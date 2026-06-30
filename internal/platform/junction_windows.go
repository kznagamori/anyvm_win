//go:build windows

package platform

import (
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"

	"golang.org/x/sys/windows"
)

const (
	// ioReparseTagMountPoint はジャンクション(マウントポイント)の reparse タグ。
	ioReparseTagMountPoint = 0xA0000003
	// fsctlSetReparsePoint は FSCTL_SET_REPARSE_POINT 制御コード。
	fsctlSetReparsePoint = 0x000900A4
)

// createJunction は link を target を指すディレクトリジャンクションとして作成する。
//
// シンボリックリンクと異なり、ジャンクションは非特権ユーザーでも作成できるため、
// 旧実装の `cmd /C MKLINK /J` と等価な振る舞いを、外部プロセスに依存せず実現する
// （.doc/08 §2、.doc/04 §1 の外部依存削減）。
//
// 注: 本関数の実行時挙動は Windows 実機での検証が必要（本リポジトリの CI は
// クロスビルドでのコンパイル確認まで）。reparse バッファの構造は
// REPARSE_DATA_BUFFER(MountPoint) の標準レイアウトに従う。
func createJunction(link, target string) error {
	abs, err := filepath.Abs(target)
	if err != nil {
		return err
	}

	// ジャンクションは空ディレクトリに対して設定する。
	if err := os.Mkdir(link, 0o755); err != nil {
		return err
	}
	success := false
	defer func() {
		// reparse 設定に失敗した場合は作成したディレクトリを後始末する。
		if !success {
			_ = os.Remove(link)
		}
	}()

	// SubstituteName は "\??\<target>"、PrintName は "<target>"（いずれも UTF-16, NUL 終端）。
	sub16 := windows.StringToUTF16(`\??\` + abs)
	print16 := windows.StringToUTF16(abs)
	subByteLen := (len(sub16) - 1) * 2 // NUL を除く長さ
	printByteLen := (len(print16) - 1) * 2

	// REPARSE_DATA_BUFFER を組み立てる。
	//   固定ヘッダ(8) = ReparseTag(4) + ReparseDataLength(2) + Reserved(2)
	//   MountPoint ヘッダ(8) = SubstituteNameOffset/Length + PrintNameOffset/Length（各2）
	//   PathBuffer = SubstituteName(UTF16, NUL含) + PrintName(UTF16, NUL含)
	pathBufBytes := (len(sub16) + len(print16)) * 2
	dataLen := 8 + pathBufBytes // ReparseDataLength（固定ヘッダを除く長さ）
	buf := make([]byte, 8+dataLen)

	binary.LittleEndian.PutUint32(buf[0:], ioReparseTagMountPoint)
	binary.LittleEndian.PutUint16(buf[4:], uint16(dataLen))
	binary.LittleEndian.PutUint16(buf[6:], 0) // Reserved
	binary.LittleEndian.PutUint16(buf[8:], 0) // SubstituteNameOffset
	binary.LittleEndian.PutUint16(buf[10:], uint16(subByteLen))
	binary.LittleEndian.PutUint16(buf[12:], uint16(subByteLen+2)) // PrintNameOffset（Sub の NUL の後）
	binary.LittleEndian.PutUint16(buf[14:], uint16(printByteLen))

	off := 16
	for _, w := range sub16 {
		binary.LittleEndian.PutUint16(buf[off:], w)
		off += 2
	}
	for _, w := range print16 {
		binary.LittleEndian.PutUint16(buf[off:], w)
		off += 2
	}

	// reparse point を設定するため、リンクディレクトリを開く。
	linkPtr, err := windows.UTF16PtrFromString(link)
	if err != nil {
		return err
	}
	h, err := windows.CreateFile(
		linkPtr,
		windows.GENERIC_WRITE,
		0,
		nil,
		windows.OPEN_EXISTING,
		windows.FILE_FLAG_OPEN_REPARSE_POINT|windows.FILE_FLAG_BACKUP_SEMANTICS,
		0,
	)
	if err != nil {
		return fmt.Errorf("リンクディレクトリのオープン: %w", err)
	}
	defer windows.CloseHandle(h)

	var bytesReturned uint32
	if err := windows.DeviceIoControl(
		h, fsctlSetReparsePoint, &buf[0], uint32(len(buf)), nil, 0, &bytesReturned, nil,
	); err != nil {
		return fmt.Errorf("reparse point の設定: %w", err)
	}
	success = true
	return nil
}
