;版本13. Gemini pro 对版本10进行按必要要点优化
#Requires AutoHotkey v2.0

; ==============================================================================
;   脚本名称：中英文标点转换器 (优化版)
;   优化说明：
;   1. 使用 Map() 替代字符串查找，时间复杂度 O(n) -> O(1)
;   2. 合并 Config 遍历循环，减少初始化开销
;   3. InputHook 仅监控标点键，减少回调
;   4. 移除冗余 physicalKeys 判定
;   5. 增强剪贴板设置的可靠性
;   6. 增加 OnExit 显式资源清理
;   7. 缓存 GetFocusedHwnd，减少重复系统调用
; ==============================================================================

class CnEnPunctSwitcher {
    
    ; --------------------------------------------------------------------------
    ;   1. 配置区
    ; --------------------------------------------------------------------------
    static Config := [
        {Key: ",",   Cn: "，", En: ","},      ; 逗号
        {Key: ".",   Cn: "。", En: "."},      ; 句号
        {Key: ";",   Cn: "；", En: ";"},      ; 分号
        ;{Key: "[",   Cn: "【", En: "["},      ; 左方括号
        ;{Key: "]",   Cn: "】", En: "]"},      ; 右方括号
        {Key: "\",   Cn: "、", En: "\"},      ; 顿号
        {Key: "``",  Cn: "·",  En: "``"},     ; 间隔号
        {Key: "+;",  Cn: "：", En: ":"},      ; 冒号
        {Key: "+1",  Cn: "！", En: "!"},      ; 感叹号
        {Key: "+/",  Cn: "？", En: "?"},      ; 问号
        {Key: "+9",  Cn: "（", En: "("},      ; 左括号
        {Key: "+0",  Cn: "）", En: ")"},      ; 右括号
        {Key: "+,",  Cn: "《", En: "<"},      ; 左书名号
        {Key: "+.",  Cn: "》", En: ">"}       ; 右书名号
    ]

    ; --------------------------------------------------------------------------
    ;   2. 内部状态变量
    ; --------------------------------------------------------------------------
    static SymbolMap := Map()    ; 中文标点 -> 英文标点
    static LastHotkey := ""      ; 记录上一次按的热键
    static PunctVKMap := Map()   ; 虚拟码集合 (O(1) 查找)
    static IH := ""              ; InputHook 监听器

    ; --------------------------------------------------------------------------
    ;   3. 启动器
    ;   异常：任一子步骤失败时弹窗提示，并终止后续初始化
    ; --------------------------------------------------------------------------
    static Start() {
        try {
            this.InitializeMaps()
        } catch as e {
            MsgBox("【InitializeMaps 失败】`n" e.Message "`n`n" e.Stack, "CnEnPunctSwitcher 启动错误", "Icon!")
            return
        }

        try {
            this.SetupInputHook()
        } catch as e {
            MsgBox("【SetupInputHook 失败】`n" e.Message "`n`n" e.Stack, "CnEnPunctSwitcher 启动错误", "Icon!")
            return
        }

        try {
            this.RegisterHotkeys()
        } catch as e {
            MsgBox("【RegisterHotkeys 失败】`n" e.Message "`n`n" e.Stack, "CnEnPunctSwitcher 启动错误", "Icon!")
            return
        }
        
        ; 注册退出时的清理回调
        OnExit(this.Cleanup.Bind(this))
    }
    
    ; --------------------------------------------------------------------------
    ;   清理回调：显式停止 InputHook
    ; --------------------------------------------------------------------------
    static Cleanup(*) {
        if this.IH
            this.IH.Stop()
    }

    ; --------------------------------------------------------------------------
    ;   4. 初始化映射表
    ;   异常：Config 项的 Key 无法解析为虚拟键码时，收集所有问题项并统一弹窗
    ; --------------------------------------------------------------------------
    static InitializeMaps() {
        invalidKeys  := []          ; 收集无效 Key，用于统一报告

        for item in this.Config {
            ; 构建 SymbolMap
            this.SymbolMap[item.Cn] := item.En

            ; 构建 PunctVKMap
            pureKey := StrReplace(item.Key, "+", "")
            vkCode  := GetKeyVK(pureKey)

            if !vkCode {
                ; 记录无效项，继续遍历其余项
                invalidKeys.Push("Key='" item.Key "' (pureKey='" pureKey "')")
                continue
            }

            ; 直接使用 PunctVKMap 判断，省去 physicalKeys Map
            if !this.PunctVKMap.Has(vkCode) {
                this.PunctVKMap[vkCode] := true
            }
        }

        ; 遍历结束后统一报告无效项（避免弹多个框）
        if invalidKeys.Length > 0 {
            msg := "【InitializeMaps】以下 Config 项的 Key 无法解析为虚拟键码，已跳过：`n`n"
            for entry in invalidKeys
                msg .= "  · " entry "`n"
            MsgBox(msg, "CnEnPunctSwitcher 配置警告", "Icon!")
        }
    }

    ; --------------------------------------------------------------------------
    ;   5. 设置键盘监听器
    ;   （异常由 Start 的 try-catch 捕获）
    ; --------------------------------------------------------------------------
    static SetupInputHook() {
        this.IH := InputHook("V L0")
        
        ; 通过 KeyOpt 仅对标点键开启回调通知(N)，避免监控所有按键
        for vkCode in this.PunctVKMap {
            this.IH.KeyOpt("{vk" Format("{:X}", vkCode) "}", "N")
        }
        
        this.IH.OnKeyDown := this.ResetIfNotPunct.Bind(this)
        this.IH.Start()
    }

    ; --------------------------------------------------------------------------
    ;   6. 重置状态的回调函数
    ; --------------------------------------------------------------------------
    static ResetIfNotPunct(ih, vk, sc) {
        if !this.PunctVKMap.Has(vk)
            this.LastHotkey := ""
    }

    ; --------------------------------------------------------------------------
    ;   7. 注册热键
    ;   异常：单个热键注册失败时弹窗，但继续注册其余热键
    ; --------------------------------------------------------------------------
    static RegisterHotkeys() {
        failedKeys := []

        for item in this.Config {
            try {
                Hotkey("~" item.Key, this.HandleKey.Bind(this, item.Cn))
            } catch as e {
                failedKeys.Push("Key='" item.Key "': " e.Message)
            }
        }

        if failedKeys.Length > 0 {
            msg := "【RegisterHotkeys】以下热键注册失败：`n`n"
            for entry in failedKeys
                msg .= "  · " entry "`n"
            MsgBox(msg, "CnEnPunctSwitcher 热键注册警告", "Icon!")
        }
    }

    ; --------------------------------------------------------------------------
    ;   8. 核心转换逻辑
    ;   异常：SymbolMap 中找不到对应字符时弹窗（理论上不应发生）
    ; --------------------------------------------------------------------------
    static HandleKey(char, *) {
        ; 在单次连击流程顶层获取一次 Hwnd 并向下传递，避免同一次按键重复 DllCall 获取
        hwnd := this.GetFocusedHwnd()
        
        if !this.IsIMECnMode(hwnd)
            return

        if (A_PriorHotkey = A_ThisHotkey 
            && A_TimeSincePriorHotkey < 500 
            && this.LastHotkey = A_ThisHotkey) {

            ; 防御：检查映射表中是否存在该字符
            if !this.SymbolMap.Has(char) {
                MsgBox("【HandleKey】SymbolMap 中找不到字符：'" char "'`n热键：" A_ThisHotkey, "CnEnPunctSwitcher 运行错误", "Icon!")
                this.LastHotkey := ""
                return
            }

            if GetKeyState("Shift", "P")
                KeyWait("Shift")

            savedMode := this.GetIMEConvMode(hwnd)
            Send("{BackSpace 2}")
            this.SafeSendText(this.SymbolMap[char])

            if (savedMode != -1)
                this.RestoreIMEMode(savedMode, hwnd)

            this.LastHotkey := ""
        } else {
            this.LastHotkey := A_ThisHotkey
        }
    }

    ; --------------------------------------------------------------------------
    ;   9. 智能发送文本
    ;   异常：剪贴板等待超时或粘贴失败时弹窗，并记录回退路径
    ; --------------------------------------------------------------------------
    static SafeSendText(str) {
        try {
            savedClip := ClipboardAll()
            A_Clipboard := ""    ; 先清空剪贴板，确保后续 ClipWait 判定准确
            A_Clipboard := str

            if ClipWait(0.5) {
                Send("^v")
                Sleep 50
            } else {
                ; ClipWait 超时：剪贴板未能在 0.5s 内更新
                MsgBox("【SafeSendText】ClipWait 超时，剪贴板未能及时更新。`n将回退至 SendText 发送：'" str "'", "CnEnPunctSwitcher 警告", "Icon!")
                SendText(str)
            }

            A_Clipboard := savedClip
        } catch as e {
            MsgBox("【SafeSendText】发生异常，已回退至 SendText。`n`n错误：" e.Message "`n`n" e.Stack, "CnEnPunctSwitcher 运行错误", "Icon!")
            SendText(str)
        }
    }

    ; --------------------------------------------------------------------------
    ;   底层代码区
    ;   注：此区函数被每次按键调用，不在此弹窗，异常值由上层处理
    ;   注2：支持传入已缓存的 hwnd 减少重复 DllCall
    ; --------------------------------------------------------------------------

    static GetIMEOpenStatus(hwnd := 0) {
        return this.SendIMEMessage(0x005, 0, hwnd)  ; IMC_GETOPENSTATUS
    }

    static IsIMECnMode(hwnd := 0) {
        mode := this.GetIMEConvMode(hwnd)
        if (mode == -1)
            return false
        ; Win32 应用：0x400 位可靠，优先使用
        if (mode & 0x400)
            return true
        ; TSF 应用：0x400 位丢失，改用 IME 开关状态区分中/英文
        if (mode & 0x1)
            return (this.GetIMEOpenStatus(hwnd) == 1)
        return false
    }

    static GetFocusedHwnd() {
        if foreHwnd := WinExist("A") {
            size := A_PtrSize == 8 ? 72 : 48
            guiThreadInfo := Buffer(size)
            NumPut("uint", size, guiThreadInfo)
            if DllCall("GetGUIThreadInfo", "uint", DllCall("GetWindowThreadProcessId", "ptr", foreHwnd, "ptr", 0, "uint"), "ptr", guiThreadInfo) {
                if focusedHwnd := NumGet(guiThreadInfo, A_PtrSize == 8 ? 16 : 12, "ptr")
                    return focusedHwnd
            }
            return foreHwnd
        }
        return 0
    }

    static GetIMEConvMode(hwnd := 0) {
        return this.SendIMEMessage(0x001, 0, hwnd)
    }

    static RestoreIMEMode(savedMode, hwnd := 0) {
        this.SendIMEMessage(0x002, savedMode, hwnd)
    }

    static SendIMEMessage(wParam, lParam, hwnd := 0) {
        static WM_IME_CONTROL := 0x283
        if !hwnd
            hwnd := this.GetFocusedHwnd()
            
        ; hwnd == 0：无前台窗口，属于正常边界情况，静默返回 -1
        if !hwnd
            return -1
        imeHwnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
        ; imeHwnd == 0：TSF 应用或无 IME 窗口，静默返回 -1，由上层 IsIMECnMode 处理
        if !imeHwnd
            return -1
        DllCall("SendMessageTimeoutW", "ptr", imeHwnd, "uint", WM_IME_CONTROL,
            "ptr", wParam, "ptr", lParam, "uint", 0, "uint", 500, "ptr*", &result := 0)
        return result
    }
}

; ==============================================================================
;   启动脚本
; ==============================================================================
CnEnPunctSwitcher.Start()