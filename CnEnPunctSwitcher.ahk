#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 中英文标点连击切换 · 结构优化版
; 功能：中文输入法下，连击标点 → 自动切换为英文标点
; 特点：稳定、低占用、无侵入、可配置
; ==============================================================================

; ------------------------------------------------------------------------------
; 主类：标点切换器
; ------------------------------------------------------------------------------
class CnEnPunctSwitcher
{
    ; --------------------------------------------------------------------------
    ; 【1】用户可配置常量（全部集中在这里）
    ; --------------------------------------------------------------------------
    static DOUBLE_CLICK_INTERVAL := 800  ; 连击间隔（毫秒）
    static IME_CACHE_TIME := 50         ; IME状态缓存时间（性能优化）

    ; --------------------------------------------------------------------------
    ; 【2】标点配置表（统一管理，未来新增标点只需加一行）
    ; --------------------------------------------------------------------------
    static PUNCTUATION_MAP := [
        { Key: ",",     PhysKey: ",",   Cn: "，",  En: ","  },
        { Key: ".",     PhysKey: ".",   Cn: "。",  En: "."  },
        { Key: ";",     PhysKey: ";",   Cn: "；",  En: ";"  },
        { Key: "SC02B", PhysKey: "\\",  Cn: "、",  En: "\\" },  ; 反斜杠（扫描码）
        { Key: "``",    PhysKey: "``",  Cn: "·",   En: "``" },  ; 反引号
        { Key: "+;",    PhysKey: ";",   Cn: "：",  En: ":"  },  ; Shift + ;
        { Key: "+1",    PhysKey: "1",   Cn: "！",  En: "!"  },  ; Shift + 1
        { Key: "+/",    PhysKey: "/",   Cn: "？",  En: "?"  },  ; Shift + /
        { Key: "+9",    PhysKey: "9",   Cn: "（",  En: "("  },  ; Shift + 9
        { Key: "+0",    PhysKey: "0",   Cn: "）",  En: ")"  }   ; Shift + 0
    ]

    ; --------------------------------------------------------------------------
    ; 【3】内部状态（私有变量，统一存放）
    ; --------------------------------------------------------------------------
    static __lastKey   := ""    ; 上一次物理键
    static __lastTime  := 0     ; 上一次时间
    static __cacheHwnd := 0     ; IME缓存窗口
    static __cacheTick := 0     ; IME缓存时间
    static __cacheRes  := false ; IME缓存结果

    ; --------------------------------------------------------------------------
    ; 【4】公开入口：启动
    ; --------------------------------------------------------------------------
    static Start() {
        this.__registerHotkeys()
    }

    ; --------------------------------------------------------------------------
    ; 【5】内部：注册所有热键
    ; --------------------------------------------------------------------------
    static __registerHotkeys() {
        for cfg in this.PUNCTUATION_MAP {
            Hotkey("~" cfg.Key, this.__onKeyPress.Bind(this, cfg))
        }
    }

    ; --------------------------------------------------------------------------
    ; 【6】核心：按键触发逻辑
    ; --------------------------------------------------------------------------
    static __onKeyPress(cfg, *) {
        now := A_TickCount

        ; 快速判断：是否可能连击
        isDoubleClick := (cfg.PhysKey == this.__lastKey && now - this.__lastTime < this.DOUBLE_CLICK_INTERVAL)

        ; 更新状态（无论是否触发都要更新）
        this.__lastKey  := cfg.PhysKey
        this.__lastTime := now

        ; 非连击直接退出
        if (!isDoubleClick)
            return

        ; 只有连击才检查输入法
        if (!this.__isChineseIMEMode())
            return

        ; 执行切换
        Send("{Blind}{BS 2}")
        SendText(cfg.En)

        ; 防止三连击
        this.__lastTime := 0
    }

    ; --------------------------------------------------------------------------
    ; 【7】内部：IME 中文状态检测（带缓存）
    ; --------------------------------------------------------------------------
    static __isChineseIMEMode() {
        try {
            hwnd := WinExist("A")
            now  := A_TickCount

            ; 缓存命中：直接返回
            if (hwnd = this.__cacheHwnd && now - this.__cacheTick < this.IME_CACHE_TIME)
                return this.__cacheRes

            ; 获取焦点句柄
            focused := this.__getFocusedHwnd(hwnd)
            imeHwnd  := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", focused, "Ptr")
            res      := false

            if (imeHwnd) {
                imeRet := 0
                DllCall("SendMessageTimeout", "Ptr", imeHwnd, "UInt", 0x283,
                        "Ptr", 0x005, "Ptr", 0, "UInt", 0, "UInt", 50, "Ptr*", &imeRet)
                res := !!(imeRet & 1)
            }

            ; 更新缓存
            this.__cacheHwnd := hwnd
            this.__cacheTick := now
            this.__cacheRes  := res
            return res
        } catch {
            return false
        }
    }

    ; --------------------------------------------------------------------------
    ; 【8】内部：获取真正焦点控件
    ; --------------------------------------------------------------------------
    static __getFocusedHwnd(hwnd) {
        threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
        size     := A_PtrSize = 8 ? 72 : 48
        info     := Buffer(size, 0)
        NumPut("UInt", size, info)

        if (DllCall("GetGUIThreadInfo", "UInt", threadId, "Ptr", info)) {
            offset := A_PtrSize = 8 ? 16 : 12
            return NumGet(info, offset, "Ptr") || hwnd
        }
        return hwnd
    }
}

; 启动
CnEnPunctSwitcher.Start()