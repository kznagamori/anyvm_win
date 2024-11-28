# Any Version Management For Windows (anyvm_win)
開発ツールのバージョンを管理するツール


## 1. コンセプト

- Windowsでプログラミングがしたい。
- Linuxで使用される**anyenv**のように開発ツールのバージョン管理を行いたい。
- Windowsの環境（レジストリやインストールアプリケーションなど）に影響を与えないようにしたい。
- **anyenv**が起動シェル（`.bashrc`など）でバージョンを管理しているように、Windowsでも起動シェルで管理したい。

上記コンセプトをもとに作成しました。



## 2. システムイメージ

- 開発ツールは、**Powershell（pwsh）**や**コマンドプロンプト**で使用することを想定しています。
- **VSCode**は、**Powershell（pwsh）**や**コマンドプロンプト**から起動することで、本ツールの機能を使用できます。
- **anyenv**は`global`、localの概念があったが、set/unsetでバージョン切り替えのみ。
- **Powershell（pwsh）** は、起動時に自動実行するスクリプトがあり、そこから本ツールのスクリプトを実行することで本ツールの機能を使用できます。
- **コマンドプロンプト**はレジストリに起動時に自動実行するバッチファイルを設定することができます。そのバッチファイルから本ツールのバッチファイルを実行することで本ツールの機能を使用できます。
- 使い方でWindows環境への影響度が決められます。



### 2.1. Windows環境への影響度

#### 2.1.1. 影響度: 低

開発ツールを使用する前に、本ツールのスクリプトもしくはバッチファイルを毎回実行することで、開発ツールを使用できる状態にします。

本ツールを使用する場合は、展開した先のスクリプトを呼び出して使用します。

- Powershell(pwsh)： `<anyvm_winフォルダーのパス>\bin\anyvm.ps1`
- コマンドプロンプト：`<anyvm_winフォルダーのパス>\bin\anyvm.bat`



本ツールのスクリプトもしくはバッチファイルを実行しない限り開発ツールを使用できる状態にならないため、Windows環境への影響度は低く（ほとんどなし）となります。実行するスクリプトは以下となります。

- Powershell(pwsh)： `<anyvm_winフォルダーのパス>\scripts\AnyVmActivate.ps1`
- コマンドプロンプト：`<anyvm_winフォルダーのパス>\scripts\AnyVmActivate.bat`



#### 2.1.2. 影響度: 中

**Powershell（pwsh）**やコマンドプロンプトは、起動時に自動実行するスクリプトで**anyvm_win**のスクリプトを実行します。**anyvm_win**で開発ツールを有効・無効を切り替えることで、Windows環境への影響度を設定します。



#### 2.1.3. 影響度: 高

自身で開発環境へのパスを設定することで、**Powershell（pwsh）**や**コマンドプロンプト**から起動しなくても開発ツールが使用できる状態にできます。ただし、他の開発ツールとコンフリクトする可能性があります。
anyvm_winは有効化したツールは以下のディレクトリにジャンクションが張られます。このパスを環境変数のパスに追加することで、anyvm_winで有効化した開発ツールが使用できるようになります。各開発ツールへのジャンクションは以下となります。

`anyvm_win\envs\<開発ツール>\current`



## 3. インストール

### 3.1. anyvm_winの取得

[anyvm_win.zip](https://github.com/kznagamori/anyvm_win/releases/download/v1.0.1/anyvm_win.zip)をダウンロードし、anyvm_winと環境を保存するディレクトリに展開します。
anyvm_winは以下のファイルから構成されています。

```
anyvm_win
├── bin
│   ├── anyvm.bat
│   ├── anyvm.ps1
│   ├── anyvm_win.exe
│   ├── bazel_vm_version_cache.json
│   ├── cmake_vm_version_cache.json
│   ├── dart_vm_version_cache.json
│   ├── dotnet_vm_version_cache.json
│   ├── flutter_vm_version_cache.json
│   ├── go_vm_version_cache.json
│   ├── gradle_vm_version_cache.json
│   ├── jdk_vm_version_cache.json
│   ├── kotlin_vm_version_cache.json
│   ├── llvm_vm_version_cache.json
│   ├── mingw_vm_version_cache.json
│   ├── ninja_vm_version_cache.json
│   ├── nodejs_vm_version_cache.json
│   ├── python_vm_version_cache.json
│   └── rust_vm_version_cache.json
├── scripts
│   ├── AnyVmActivate.bat
│   ├── AnyVmActivate.ps1
│   ├── AnyVmDeactivate.bat
│   └── AnyVmDeactivate.ps1
├── setup_jp.bat
└── tools
    └── symexe.exe
```



### 3.2. anyvm_winのセットアップ開始

1. コマンドプロンプトを立ち上げます。
2. anyvm_winを展開したディレクトリに移動します。

### 3.3. 起動時自動実行スクリプトの設定

**※2.1.2. 影響度: 中で使用する場合のみ、この手順を行ってください。**

下記のコマンドは`D:`以下に`anyvm_win`を展開した場合の例となっています。

`setup_jp.bat`を実行します。

```powershell
D:\anyvm_win>.\setup_jp.bat
```



`setup_jp.bat`を実行することで、起動時自動実行スクリプトの作成や設定が行われます。実行時以下の質問がされます。

- Powershellの実行ポリシーをRemoteSignedに変更しますか？(Y=YES / N=NO): 
  - Powershellでスクリプトが実行できるように設定を変更します。
  - 以下のコマンドが実行されます。
    - `powershell -Command Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`
  - セキュリティが低下しますので、問題がある場合は行わないでください。
- <Powershellスクリプトのパス>を作成しますか？(Y=YES / N=NO): 
  -  Powershellの起動時自動実行スクリプトの作成を行います。
- <Powershellスクリプトのパス>にパスを追記しますか？(Y=YES / N=NO): 
  - Powershellの起動時自動実行スクリプトにanyvm_winを使用することができるようにスクリプトを書き込みます。
- レジストリにcmdの起動バッチファイルのパスを追加しますか？(Y=YES / N=NO): 
  - レジストリにコマンドプロンプトの起動時に自動実行するバッチファイルの設定を書き込みます。
  - レジストリへの書き込みのため管理者権限が要求されることがあります。
  - 以下のキーへの書き込みが行われます。
    - `HKEY_CURRENT_USER\Software\Microsoft\Command Processor`の`AutoRun`
- <起動バッチファイルのパス>にパスを追記しますか？(Y=YES / N=NO): 
  - コマンドプロンプトの起動時に自動実行するバッチファイルにanyvm_winを使用することができるようにスクリプトを書き込みます。
- <pwshスクリプトのパス>を作成しますか？(Y=YES / N=NO): 
  -  pwshの起動時自動実行スクリプトの作成を行います。
- <pwshスクリプトのパス>にパスを追記しますか？(Y=YES / N=NO): 
  - pwshの起動時自動実行スクリプトにanyvm_winを使用することができるようにスクリプトを書き込みます。



### 3.4. anyvm_winの初期化

**anyvm_win**の初期化コマンドを実行します。

```powershell
D:\anyvm_win>.\bin\anyvm.bat init
```



以上でanyvm_winのインストールは完了します。



## 4. 使用方法

anyvm_winは`anyvm <開発ツール名> <コマンド> <オプション> ...`で使用します。

以下はanyvm_winでインストールしたPythonのバージョン一覧を表示する例です。

```
PS C:\> anyvm PythonVm versions
 3.10.11
*3.11.8
 3.12.2
 3.8.10
```

### 4.1. 開発ツール名
現在サポートする開発ツールは以下となります。

| 開発ツール名 | 開発ツール | 備考                                                         |
| ------------ | ---------- | ------------------------------------------------------------ |
| BazelVm      | Bazel      | https://bazel.build/?hl=ja                                   |
| CMakeVm      | CMake      | https://cmake.org/                                           |
| DartVm       | Dart       | https://dart.dev/                                            |
| FlutterVm    | Flutter    | https://flutter.dev/                                         |
| GoVm         | Go         | https://go.dev/                                              |
| LLVMVm       | LLVM       | https://github.com/llvm/llvm-project                         |
| MinGWVm      | MinGW      | https://github.com/niXman/mingw-builds-binaries<br>MinGWを使用する場合は、anyvm_winを日本語やスペースを含まないパスに配置する必要があります。 |
| NinjaVm      | Ninja      | https://ninja-build.org/                                     |
| NodejsVm     | Node.js    | https://nodejs.org/                                          |
| PythonVm     | Python     | https://www.python.org/                                      |
| RustVm       | Rust       | https://www.rust-lang.org/<br>Rustはrustupでのバージョン管理を想定しているため、anyvm_winではバージョンの設定はできません。 |
| dotnetVm     | .NET       | https://dotnet.microsoft.com/                                |
| AndroidSDKVm | Android Studio<br>コマンドライン ツール       | https://developer.android.com/studio<br>最新版のインストールのみ対応                                |
| JDKVm        | OpenJDK    | https://adoptium.net/                                        |
| GradleVm     | Gradle     | https://gradle.org/                                          |
| KotlinVm     | Kotlin     | https://kotlinlang.org/                                      |

### 4.2. コマンド
`anyvm <開発ツール名> <コマンド> <オプション> ...` で実行を行います。

| コマンド | オプション１    | オプション２ | 説明                                                         |
| -------- | --------------- | ------------ | ------------------------------------------------------------ |
| install  | -l or --list    |              | インストール可能なバージョンの一覧を表示する。（※1）         |
| install  | -v or --version | バージョン   | 指定されたバージョンの開発ツールをインストールする。 <br>バージョンには※1で表示されるバージョンを指定する必要がある。 |
| install  | --latest       |              | 最後のバージョンの開発ツールをインストールする。             |
| uinstall | -v or --version | バージョン   | 指定したバージョンの開発ツールをアンインストールします。     |
| set      | -v or --version | バージョン   | 指定したバージョンの開発ツールを有効化します。               |
| unset    |                 |              | 開発ツールを無効化します。                                   |
| version  |                 |              | 有効になっているバージョンを表示します。                     |
| versions |                 |              | インストールされているバージョンの一覧を表示します。         |
| update   |                 |              | インストール可能なバージョンの検索を行います。<br>実行する場合はgitコマンドにパスが通っている必要があります。 |

#### 4.3. 全体コマンド
`anyvm <コマンド>` で実行を行います。

| コマンド | 説明                                                         |
| -------- | ------------------------------------------------------------ |
| init     | インストールやanyvm自身の更新時に行うコマンド         |
| rehash   | 開発ツールの環境変数を更新します。<br> setやunsetを行った後に実行する必要があります。|
| unset    | すべての開発ツールのunsetを実行します。             |
| update   | すべての開発ツールのインストール可能なバージョンの検索を行います。<br>実行する場合はgitコマンドにパスが通っている必要があります。 |


### 4.4. 例

#### 4.4.1. インストール可能なPythonのバージョン一覧を表示する

```powershell
PS C:\> anyvm PythonVm install -l
3.8.7
3.8.8
3.8.9
3.8.10
3.9.1
3.9.2
3.9.4
3.9.5
3.9.6
3.9.7
3.9.8
3.9.9
3.9.10
3.9.11
3.9.12
3.9.13
3.10.0
3.10.1
3.10.2
3.10.3
3.10.4
3.10.5
3.10.6
3.10.7
3.10.8
3.10.9
3.10.10
3.10.11
3.11.0
3.11.1
3.11.2
3.11.3
3.11.4
3.11.5
3.11.6
3.11.7
3.11.8
3.11.9
3.12.0
3.12.1
3.12.2
3.12.3
3.12.4
```



#### 4.4.2. バージョン3.9.13のPythonをインストールする。

```powershell
PS C:\> anyvm PythonVm install --version 3.9.13
Download D:\repos\anyvm_win\envs\python\install-cache\python-3.9.13-amd64.exe from https://www.python.org/ftp/python/3.9.13/python-3.9.13-amd64.exe
[========================================] 100.00%
Download complete.
D:\repos\anyvm_win\envs\python\3.9.13 creatred
Directory renamed/moved successfully.:Directory: 'D:\repos\anyvm_win\envs\python\install-cache\3.9.13'
File deleted successfully.: D:\repos\anyvm_win\envs\python\install-cache\python-3.9.13-amd64.exe
```



#### 4.4.3. インストールされているバージョンを確認する。

```powershell
PS C:\> anyvm PythonVm versions
 3.10.11
 3.11.8
 3.12.2
 3.8.10
 3.9.13
```

※本作業を行う前に、様々なバージョンのPythonをインストールしています。



#### 4.4.4. バージョン3.9.13のPythonを有効する。

```powershell
PS C:\> anyvm PythonVm set --version 3.9.13
Junction created: D:\repos\anyvm_win\envs\python\current -> D:\repos\anyvm_win\envs\python\3.9.13
D:\repos\anyvm_win\scripts\PythonVmActivate.bat creatred
D:\repos\anyvm_win\scripts\PythonVmActivate.ps1 creatred
D:\repos\anyvm_win\scripts\PythonVmDeactivate.bat creatred
D:\repos\anyvm_win\scripts\PythonVmDeactivate.ps1 creatred
PS C:\> anyvm rehash
PS C:\> 
```



#### 4.4.5. 指定したバージョンのPythonが有効になっているか確認する。

```powershell
PS C:\> anyvm PythonVm version
3.9.13
PS C:\> python --version
Python 3.9.13
PS C:\>
```



#### 4.4.6. 開発ツールのPythonを無効化する。

```powershell
PS C:\> anyvm PythonVm unset
Directory renamed/moved successfully.:D:\repos\anyvm_win\envs\python\current
D:\repos\anyvm_win\scripts\PythonVmActivate.bat creatred
D:\repos\anyvm_win\scripts\PythonVmActivate.ps1 creatred
```



## 5. アンインストール

1. 以下のコマンドですべて開発ツールを無効にします。
```
anyvm unset
```

2. **anyvm_win**を展開ディレクトリを削除することでアンインストールすることができます。


3. **3.3. 起動時自動実行スクリプトの設定**を行った場合は、以下の作業を行う必要があります。

- Powershell（pwsh）の起動時自動実行スクリプトの削除
- コマンドプロンプトの起動バッチファイルを以下に変更する。

```bat
@ECHO OFF
```

4. NodeJSを使用した場合は、npmやyarnのキャッシュを削除する必要があります。
   npmやyarnのキャッシュディレクトリは以下となります。
- npm: `C:\Users\<YourUsername>\AppData\Local\npm-cache`
- yarn: `C:\Users\<YourUsername>\AppData\Local\Yarn\Cache`



## Appendix A： Rust

### Rustのインストール

Rustのインストールは以下のコマンドで行っています。

```
rustup-init.exe -y --no-modify-path --default-host x86_64-pc-windows-gnu --default-toolchain stable
```

Rustのツールチェインはgcc(MinGW)を使用する設定でインストールを行っています。



### Rustのツールチェイン

Rustのツールチェインは、Rustでクレート（外部パッケージ）をビルドする際に使用されるコンパイラです。
本ツールでMinGWのインストール、有効化することでクレートのビルドをすることができます。
しかし標準はVisualC++のため、一部のクレートのビルドに失敗します。

VisualStudioをインストールしている場合は、以下のコマンドでVisualStudioのコンパイラを使用することができます。

```
rustup toolchain install stable-msvc
rustup default stable-msvc
```


## Appendix B： 各開発ツールで一時的に設定される環境変数
| 開発ツール名 | 環境変数名 | 備考                                                         |
| ------------ | ---------- | ---------------------------------------------------------- |
| BazelVm      | PATH      | envs\bazel\current                                         |
| CMakeVm      | PATH      | envs\cmake\current\bin |
|  DartVm        |  PATH<br>PUB_CACHE| envs\dart\current\bin;envs\dart\\.pub-cache\bin<br>envs\dart\\.pub-cache |
| FlutterVm    | PATH<br>PUB_CACHE| envs\flutter\current\bin;envs\flutter\\.pub-cache\bin<br>envs\flutter\\.pub-cache |
| GoVm         | Path<br>GOROOT<br>GOPATH<br>GOBIN<br>GOCACHE<br>GOENV<br>GO111MODULE<br>GOMODCACHE         | envs\go\current\bin;envs\go\go\bin<br>envs\go\current<br>envs\go\go<br>envs\go\go\bin<br>envs\go\current\go-build<br>envs\go\current\env<br>on<br>envs\go\current\pkg\mod |
| LLVMVm       | PATH<br>LIBCLANG_PATH | envs\llvm\current\bin<br>envs\llvm\current\bin |
| MinGWVm      | PATH      | envs\mingw\current\bin;envs\mingw\current\x86_64-w64-mingw32\bin |
| NinjaVm      | PATH      | envs\ninja\current                                     |
| NodejsVm     | PATH    | envs\nodejs\current                                          |
| PythonVm     | PATH     | envs\python\current;envs\python\current\Scripts            |
| RustVm       | PATH<br>RUSTUP_HOME<br>CARGO_HOME<br>RUSTUP_DIST_SERVER<br>RUSTUP_DIST_ROOT | envs\rust\\.cargo\bin<br>envs\rust\\.rustup<br>envs\rust\\.cargo<br>https://static.rust-lang.org<br>https://static.rust-lang.org/rustup |
| dotnetVm | PATH<br>DOTNET_ROOT<br>DOTNET_ROOT(x86)<br>DOTNET_CLI_HOME<br>DOTNET_ADD_GLOBAL_TOOLS_TO_PATH<br>DOTNET_CLI_TELEMETRY_OPTOUT<br>NUGET_PACKAGES<br>NUGET_FALLBACK_PACKAGES<br>NUGET_HTTP_CACHE_PATH<br>NUGET_PERSIST_DG | envs\dotnet\current;envs\dotnet\\.dotnet\tools<br>envs\dotnet\current<br>envs\dotnet\current<br>\envs\dotnet<br>false<br>true<br>\envs\dotnet\nuget\packages<br>\envs\dotnet\nuget\fallback_packages<br>envs\dotnet\nuget\http_cache_path<br>\envs\dotnet\nuget\persist_dg|
| AndroidSDKVm | PATH<br>ANDROID_SDK_ROOT<br>ANDROID_HOME       | envs\AndroidSDK\current\platform-tools;envs\AndroidSDK\current\cmdline-tools\latest\bin;envs\AndroidSDK\current\emulator<br>envs\AndroidSDK\current<br>\envs\AndroidSDK\current                                |
| JDKVm        | PATH<br>JAVA_HOME | envs\jdk\current\bin<br>envs\jdk\current |
| GradleVm     | PATH<br>GRADLE_HOME<br>GRADLE_USER_HOME | envs\gradle\current\bin<br>envs\gradle\current<br>envs\gradle\cache  |
| KotlinVm     | PATH     | envs\kotlin\current\bin                    |



