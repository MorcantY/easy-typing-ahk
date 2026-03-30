; 自定义的函数写在这个文件里,  然后能在 MyKeymap 中调用

; 使用如下写法，来加载当前目录下的其他 AutoHotKey v2 脚本
;#Include ../data/test.ahk
#Include ../data/SymbolFunc.ahk

sendSomeChinese() {
  Send("{text}你好中文!")
}


;StartSymbolConvert()
CnEnPunctSwitcher.Start()

; 测试脚本：按 F1 打印当前 IME 转换模式
/*F1:: {
    hwnd := WinGetID("A")
    imeHwnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    convMode := SendMessage(0x283, 0x001, 0, imeHwnd)
    MsgBox("convMode = " . convMode . " (0x" . Format("{:X}", convMode) . ")")
}*/

