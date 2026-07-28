#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
; IME Mouse Cursor beta 5.6
; 半角（IME OFF）: 白い I 字マウスカーソル
; 全角（IME ON） : 赤い I 字マウスカーソル
;
; Ctrl + Alt + I : 一時停止 / 再開
; Ctrl + Alt + D : 状態を確認
; Ctrl + Alt + R : Windows標準カーソルへ戻す
; ============================================================

class Config {
    static PollMs := 80
    static HalfCursorFile := A_ScriptDir "\ibeam_half_white.cur"
    static FullCursorFile := A_ScriptDir "\ibeam_full_red.cur"
}

gEnabled := true
gLastImeState := -1
gLastResult := "未設定"
gLastError := ""

if !FileExist(Config.HalfCursorFile) || !FileExist(Config.FullCursorFile) {
    errorText := "カーソルファイルが見つかりません。`nZIPを展開したフォルダー内で実行してください。"
    MsgBox(errorText, "IMEマウスカーソル beta 5.6")
    ExitApp()
}

A_IconTip := "IMEマウスカーソル beta 5.6（半角=白 / 全角=赤）"

A_TrayMenu.Delete()
A_TrayMenu.Add("一時停止 / 再開", ToggleCursor)
A_TrayMenu.Add("状態を確認", ShowStatus)
A_TrayMenu.Add("標準カーソルへ戻す", RestoreNow)
A_TrayMenu.Add()
A_TrayMenu.Add("Windows起動時に自動起動", InstallStartup)
A_TrayMenu.Add("自動起動を解除", RemoveStartup)
A_TrayMenu.Add()
A_TrayMenu.Add("終了", ExitWithRestore)
A_TrayMenu.Default := "一時停止 / 再開"

^!i::ToggleCursor()
^!d::ShowStatus()
^!r::RestoreNow()

OnExit(RestoreOnExit)
SetTimer(UpdateMouseCursor, Config.PollMs)
UpdateMouseCursor()

UpdateMouseCursor(*) {
    global gEnabled, gLastImeState, gLastResult, gLastError

    if !gEnabled {
        return
    }

    try {
        imeOn := IsImeOn()

        if imeOn = gLastImeState {
            return
        }

        cursorFile := imeOn ? Config.FullCursorFile : Config.HalfCursorFile

        if ApplyIBeamCursor(cursorFile) {
            gLastImeState := imeOn
            gLastResult := imeOn ? "全角・日本語入力：赤" : "半角・直接入力：白"
            gLastError := ""
            A_IconTip := "IMEマウスカーソル beta 5.6：" . gLastResult
        } else {
            gLastResult := "カーソル変更に失敗"
            gLastError := "LoadImageW または SetSystemCursor が失敗しました。"
        }
    } catch as err {
        gLastResult := "エラー"
        gLastError := err.Message
    }
}

ApplyIBeamCursor(cursorFile) {
    static IMAGE_CURSOR := 2
    static LR_LOADFROMFILE := 0x0010
    static OCR_IBEAM := 32513

    hCursor := DllCall(
        "user32\LoadImageW",
        "Ptr", 0,
        "Str", cursorFile,
        "UInt", IMAGE_CURSOR,
        "Int", 32,
        "Int", 32,
        "UInt", LR_LOADFROMFILE,
        "Ptr"
    )

    if !hCursor {
        return false
    }

    ok := DllCall(
        "user32\SetSystemCursor",
        "Ptr", hCursor,
        "UInt", OCR_IBEAM,
        "Int"
    )

    if !ok {
        DllCall("user32\DestroyCursor", "Ptr", hCursor)
        return false
    }

    return true
}

IsImeOn() {
    focusHwnd := GetFocusedWindow()

    if !focusHwnd {
        focusHwnd := WinExist("A")
    }

    if !focusHwnd {
        return false
    }

    imeHwnd := DllCall(
        "imm32\ImmGetDefaultIMEWnd",
        "Ptr", focusHwnd,
        "Ptr"
    )

    if !imeHwnd {
        return false
    }

    static WM_IME_CONTROL := 0x0283
    static IMC_GETOPENSTATUS := 0x0005

    result := DllCall(
        "user32\SendMessageW",
        "Ptr", imeHwnd,
        "UInt", WM_IME_CONTROL,
        "Ptr", IMC_GETOPENSTATUS,
        "Ptr", 0,
        "Ptr"
    )

    return result != 0
}

GetFocusedWindow() {
    size := 8 + (A_PtrSize * 6) + 16
    info := Buffer(size, 0)
    NumPut("UInt", size, info, 0)

    ok := DllCall(
        "user32\GetGUIThreadInfo",
        "UInt", 0,
        "Ptr", info,
        "Int"
    )

    if !ok {
        return 0
    }

    return NumGet(info, 8 + A_PtrSize, "Ptr")
}

RestoreDefaultCursors() {
    static SPI_SETCURSORS := 0x0057

    return DllCall(
        "user32\SystemParametersInfoW",
        "UInt", SPI_SETCURSORS,
        "UInt", 0,
        "Ptr", 0,
        "UInt", 0,
        "Int"
    )
}

ToggleCursor(*) {
    global gEnabled, gLastImeState, gLastResult

    gEnabled := !gEnabled

    if gEnabled {
        gLastImeState := -1
        gLastResult := "再開"
        UpdateMouseCursor()
    } else {
        RestoreDefaultCursors()
        gLastImeState := -1
        gLastResult := "一時停止：標準カーソル"
        A_IconTip := "IMEマウスカーソル beta 5.6：一時停止中"
    }
}

RestoreNow(*) {
    global gLastImeState, gLastResult

    if RestoreDefaultCursors() {
        gLastImeState := -1
        gLastResult := "Windows標準カーソルへ復元"
        A_IconTip := "IMEマウスカーソル beta 5.6：標準カーソルへ復元"
    } else {
        errorText := "標準カーソルへ戻せませんでした。`nWindowsを再起動すれば元へ戻ります。"
        MsgBox(errorText, "IMEマウスカーソル beta 5.6")
    }
}

ShowStatus(*) {
    global gEnabled, gLastImeState, gLastResult, gLastError

    processName := "不明"

    try {
        processName := WinGetProcessName("A")
    } catch {
        processName := "不明"
    }

    if gLastImeState = 1 {
        imeText := "全角・日本語入力（赤）"
    } else if gLastImeState = 0 {
        imeText := "半角・直接入力（白）"
    } else {
        imeText := "未判定 / 標準へ復元済み"
    }

    message := "動作: " . (gEnabled ? "ON" : "一時停止")
    message .= "`nIME: " . imeText
    message .= "`nアプリ: " . processName
    message .= "`n状態: " . gLastResult

    if gLastError != "" {
        message .= "`nエラー: " . gLastError
    }

    MsgBox(message, "IMEマウスカーソル beta 5.6")
}

InstallStartup(*) {
    link := A_Startup "\IME_MouseCursor_beta5_6.lnk"

    try {
        arguments := Chr(34) . A_ScriptFullPath . Chr(34)
        FileCreateShortcut(
            A_AhkPath,
            link,
            A_ScriptDir,
            arguments,
            "IMEマウスカーソル（半角=白 / 全角=赤）"
        )
        MsgBox("Windows起動時の自動実行へ登録しました。", "IMEマウスカーソル")
    } catch as err {
        MsgBox("登録できませんでした。`n`n" . err.Message, "IMEマウスカーソル")
    }
}

RemoveStartup(*) {
    link := A_Startup "\IME_MouseCursor_beta5_6.lnk"

    try {
        if FileExist(link) {
            FileDelete(link)
        }
        MsgBox("自動実行の登録を解除しました。", "IMEマウスカーソル")
    } catch as err {
        MsgBox("解除できませんでした。`n`n" . err.Message, "IMEマウスカーソル")
    }
}

ExitWithRestore(*) {
    RestoreDefaultCursors()
    ExitApp()
}

RestoreOnExit(*) {
    try {
        RestoreDefaultCursors()
    }
}
