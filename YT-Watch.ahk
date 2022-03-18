/*
Name: YT-Watch.ahk
Description: Watching Youtube Videos as Playlist with AutoPlay
Version: v1
Authors: hsayed21 [https://github.com/hsayed21]
Link: https://github.com/hsayed21/YT-Watch.ahk
; Copyright hsayed21 2022
*/

#SingleInstance force
#NoEnv
#Persistent ; needed to keep script running
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
#Include lib\Chrome.ahk
#Include lib\JSON_Beautify.ahk

; Here Put Videos Links
urls := ["https://www.youtube.com/watch/id1","https://www.youtube.com/watch/id2"]

you := new Youtube()
you.Watch(urls)

return

;=============================================================

class Youtube
{
	; Member Variable
	countTryIframe := 1
	indexCurrentMovie := 0
	JS := this.JS_Scripts()
	ChromePID := 0
	flag := true
  ; Methods
	__New(flag:="", profile:="Profile 1")
	{
		this.flag := flag
		this.profile := profile
		if (Chromes := Chrome.FindInstances())
		{
			this.ChromeInst := {"base": Chrome, "DebugPort": Chromes.MinIndex(), "PID": this.ChromePID}
		}
		else
		{
			this.ChromeInst := new Chrome(profile,,flag)
			this.ChromePID := this.ChromeInst.PID
			this.timer := new this.Timer() ; new instance timer adblock
		}
		
		chrome_ahk_pid := "ahk_pid " . this.ChromeInst.PID

		if WinExist(chrome_ahk_pid)
		{
			WinActivate, %chrome_ahk_pid%
			this.page := Chrome.GetPageByURL("about:blank")
		}
		else
		{
			this.__New(flag,profile)
		}
		
		ToolTip ;clear tooltip

	}
	
	Watch(urls)
	{
		this.URLs := urls
		for index, value in urls
		{
			if (index >= this.indexCurrentMovie)
			{
				this.indexCurrentMovie := index
				this.Main(value)
			}
		}
		
		;~ Say Bye :)
		this.ChromeInst.Kill()
		this.page.Disconnect()
		ExitApp
	}
	
	Main(url)
	{
		if (this.countTryIframe >= 10)
		{
			this.__New(this.flag, this.profile)
		}
		else
		{
			chPID := this.ChromePID
			chrome_ahk_pid := "ahk_pid " . chPID
			if (chPID != 0 && !WinExist(chrome_ahk_pid))
			{
				;~ MsgBox Chrome is Closed, will initiate a new instance
				this.__New(this.flag, this.profile)
			}
		}
		
		ToolTip
		
		this.page.Call("Page.navigate", {"url": url})
		this.page.WaitForLoad()

		; Check Exist Iframe Tag
		this.check_play_button_exist()

		; Monitor if video end or not
		flag := true
		while (flag)
		{
			ck_ended := this.page.Evaluate(this.JS.js_check_end).value
			if(ck_ended == "true")
			{
				flag := false
			}
		}
		
	}
	
	JS_Scripts()
	{
		js_window_location_href = 
		(
			window.location.href;
		)
		
		
		js_check_div_click = 
		(
			(function () {
				var div_elem = document.querySelector('.ytp-large-play-button');
				if (div_elem)
				{
					div_elem.click();
					//return "true";
				}
				else
				{
					return "false";
				}
			})();
		)
		
		js_check_video_exist = 
		(
			(function () {
				var video_elem = document.querySelector('video');
				if (video_elem)
				{
					return "true";
				}
				else
				{
					return "false";
				}
			})();
		)
		
		js_check_video_play_loading = 
		(
			(function () {
				var video_elem = document.querySelector("video");
				if (video_elem)
				{
					video_elem.play();
					if (video_elem.readyState >= 2)
					{
						return "true";
					}
					else
					{
						return "false";
					}
				}
				else
				{
					return "false";
				}
			})();
		)
		
		js_video_fullscreen = 
		(
			document.querySelector("video").requestFullscreen();
		)
		
		js_check_end = 
		(
			(function () {
				var ck_ended = document.querySelector("video").ended;
				if(ck_ended)
				{
					return "true";
				}
				else
				{
					return "false";
				}
			})();
		)
		
		obj := {js_window_location_href: js_window_location_href, js_check_div_click: js_check_div_click, js_check_video_exist: js_check_video_exist, js_check_video_play_loading: js_check_video_play_loading, js_video_fullscreen:js_video_fullscreen, js_check_end:js_check_end }
		
		return obj
		
	}
	
	reload_page()
	{
		url := this.page.Evaluate(this.JS.js_window_location_href).value
		this.page.Call("Page.navigate", {"url": url})
		this.page.WaitForLoad()
	}
	
	check_play_button_exist()
	{
		flag := true
		i := 0
		while (flag)
		{
			ck_exist := this.page.Evaluate(this.JS.js_check_div_click).value
			if (ck_exist != "false")
			{
				flag := false
				this.check_video_exist()
			}
			else
			{
				i++
				if (i >= 10)
				{
					flag := false
					this.countTryIframe := this.countTryIframe + 1
					this.ChromeInst.Kill()
					this.page.Disconnect()
					this.Movie(this.URLs) ;start again
				}
				else
				{
					Sleep, 200
					ci := this.countTryIframe
					ToolTip, button play try.no`( %ci% `) -- check existing video.. try no.`( %i% `)
					this.reload_page()
				}
			}
		}
	}
	
	check_video_exist()
	{
		flag := true
		i := 0
		result := false
		while(flag)
		{
			if (this.page.Evaluate(this.JS.js_check_video_exist).value == "true")
			{
				flag := false
				result := this.check_video_play_loading()
			}
			
			Sleep, 500
			
			if !(result)
			{
				ci := this.countTryIframe
				ToolTip, video try.no`( %ci% `) -- click | check video.. try no.`( %i% `)
				if (i >= 10)
				{
					flag := false
					this.countTryIframe := this.countTryIframe + 1
					this.ChromeInst.Kill()
					this.page.Disconnect()
					this.Movie(this.URLs) ;start again
				}
			}	
			
			Sleep, 500
			ToolTip
		}
	}
	
	check_video_play_loading()
	{
		flag := true
		flag_video_exist := false
		i := 0
		while (flag)
		{
			ck_video_loaded := this.page.Evaluate(this.JS.js_check_video_play_loading).value
			if (ck_video_loaded == "true")
			{
				ToolTip
				flag := false
				this.countTryIframe := 1
				;~ MsgBox, Everything Ok now happy watching :)
				WinActivate, % "ahk_pid " . this.ChromePID
				WinMaximize, % "ahk_pid " . this.ChromePID
				this.page.Evaluate(this.JS.js_video_fullscreen)
				return true
			}
			else
			{
				i++
			}
			
			
			if (i >= 5)
			{
				flag := false
				ToolTip, check video loading.....
				this.check_video_exist()
			}
			
			Sleep, 500
		}
	}
}


;Shortcuts
;Ctrl + ` => goto next video
^`::
flag := false
return

;Alt + Esc => Exit App
!Esc::
this.ChromeInst.Kill()
this.page.Disconnect()
ExitApp
return
