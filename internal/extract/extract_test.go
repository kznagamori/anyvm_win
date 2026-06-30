package extract

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

// TestExtractSevenZip は pure-Go 7z 展開（bodgit/sevenzip）が
// mingw64/ レイアウトの 7z を正しく展開することを検証する（mingw/llvm/winlibs 用）。
// testdata/sample.7z は mingw64/{bin/gcc.exe, README} を含む。
func TestExtractSevenZip(t *testing.T) {
	dest := t.TempDir()
	if err := (Client{}).Extract(context.Background(), "testdata/sample.7z", dest, "7z", nil); err != nil {
		t.Fatalf("Extract 7z: %v", err)
	}
	if b, err := os.ReadFile(filepath.Join(dest, "mingw64", "bin", "gcc.exe")); err != nil || string(b) != "fake-gcc" {
		t.Fatalf("mingw64/bin/gcc.exe 展開失敗: err=%v content=%q", err, string(b))
	}
	if b, err := os.ReadFile(filepath.Join(dest, "mingw64", "README")); err != nil || string(b) != "MinGW-w64" {
		t.Fatalf("mingw64/README 展開失敗: err=%v content=%q", err, string(b))
	}
}

// TestExtractUnknownFormat は未知形式がエラーになることを確認する。
func TestExtractUnknownFormat(t *testing.T) {
	if err := (Client{}).Extract(context.Background(), "testdata/sample.7z", t.TempDir(), "rar", nil); err == nil {
		t.Fatal("未知形式 rar がエラーにならなかった")
	}
}
