' 11/08/2023
' Nodel Control Script v1.0
' Troy Takac (troy@fennecdeer.com)

function Nodel_Initialize(msgPort as object, userVariables as object, bsp as object)

	'print "Custom_Initialize - entry"
	'print "type of msgPort is ";type(msgPort)
	'print "type of userVariables is ";type(userVariables)

	Nodel = newNodel(msgPort, userVariables, bsp)

	return Nodel

end function



function newNodel(msgPort as object, userVariables as object, bsp as object)
	'print "initCustom"

	' Create the object to return and set it up

	s = {}
	s.msgPort = msgPort
	s.userVariables = userVariables
	s.bsp = bsp
	s.ProcessEvent = Nodel_ProcessEvent
	s.sTime = CreateObject("roSystemTime")
	s.HandleTimerEvent = HandleTimerEvent
	s.StartTimer = StartTimer
	s.readTimer = CreateObject("roTimer")
	s.readTimer.SetPort(s.msgPort)
	s.FirstCheck = true
	s.PluginSendMessage = PluginSendMessage
	s.Generate_SnapShot_to_Folder = Generate_SnapShot_to_Folder
	s.AddHttpHandlers = AddHttpHandlers

	s.GetStatusinfo = GetStatusinfo
	s.PlaybackZone = PlaybackZone
	s.MuteZone = MuteZone
	s.RebootPlayer = RebootPlayer

	s.Muted = false
	s.CurrentVolume = 100
	s.LastVolume = []
	s.PowerSave = false
	s.Playing = true

	s.AddStatusUrls = AddStatusUrls
	s.HandleHTTPEventPlugin = HandleHTTPEventPlugin
	s.nc = CreateObject("roNetworkConfiguration", 0)
	s.PlayerIP = ""
	s.currentConfig = ""
	s.currentConfig = s.nc.GetCurrentConfig()
	if s.currentConfig <> invalid then
		s.PlayerIP = s.currentConfig.ip4_address
		'print "eth0 IP Address "; s.currentConfig.ip4_address

	end if

	s.Storage = "SD:"
	s.Path = "/"
	s.vmPlugin = CreateObject("roVideoMode")

	s.AddHttpHandlers()
	's.StartTimer()

	return s

end function



function Generate_SnapShot_to_Folder() as boolean

	DoesSnapshotFolderExist = MatchFiles("/", "mySnap")

	if DoesSnapshotFolderExist.count() <= 0 then

		IsFoldercreationOK = CreateDirectory("mySnap")

		if IsFoldercreationOK then
			status = "true"
		else
			status = "false"
		end if

		m.bsp.diagnostics.PrintDebug(" @@@ IsFoldercreationOK ? @@@ " + status)

	else if DoesSnapshotFolderExist.count() > 0 then

		screenShotParam = CreateObject("roAssociativeArray")
		'screenShotParam["filename"] = "SD:screen.jpg"
		screenShotParam["filename"] = m.Storage + m.Path + "mySnap/LastSnapshot.jpg"
		screenShotParam["width"] = m.vmPlugin.GetResX()
		screenShotParam["height"] = m.vmPlugin.GetResY()
		screenShotParam["filetype"] = "JPEG"
		screenShotParam["quality"] = 25
		screenShotParam["async"] = 0

		screenShotTaken = m.vmPlugin.Screenshot(screenShotParam)

		'Print " @@@ Screenshot Taken @@@  " screenShotTaken

		if screenShotTaken then
			status = "true"
		else
			status = "false"
		end if

		m.bsp.diagnostics.PrintDebug(" @@@ Screenshot Taken @@@ " + status)


	end if



end function




function Nodel_ProcessEvent(event as object) as boolean

	retval = false
	print "Nodel_ProcessEvent - entry"
	print "type of m is ";type(m)
	print "type of event is ";type(event)


	if type(event) = "roHttpEvent" then
		retval = HandleHTTPEventPlugin(event, m)
	end if

	if type(event) = "roTimerEvent" then
		retval = HandleTimerEvent(event, m)

	else if type(event) = "roAssociativeArray" then

		if type(event["EventType"]) = "roString"
			if event["EventType"] = "EVENT_PLUGIN_MESSAGE" then
				if event["PluginName"] = "Nodel" then
					pluginMessage$ = event["PluginMessage"]

					'retval = HandlePluginMessageEvent(pluginMessage$)

				end if

			else if event["EventType"] = "SEND_PLUGIN_MESSAGE" then

				if event["PluginName"] = "Nodel" then
					pluginMessage$ = event["PluginMessage"]
					'retval = m.HandlePluginMessageEvent(pluginMessage$)
				end if

			end if
		end if

	end if

	return retval

end function


function HandleHTTPEventPlugin(origMsg as object, Custom as object) as boolean

	userData = origMsg.GetUserData()

	if type(userdata) = "roAssociativeArray" and type(userdata.HandleEvent) = "roFunction" then
		userData.HandleEvent(userData, origMsg)

	end if

end function


sub AddHttpHandlers()

	'the main autorun local webserver already has that variable name!!!
	'm.localServer = CreateObject("roHttpServer", { port: 8081 })
	'm.localServer.SetPort(m.msgPort)
	m.pluginLocalWebServer = CreateObject("roHttpServer", { port: 8081 })
	m.pluginLocalWebServer.SetPort(m.msgPort)
	m.AddStatusUrls()

end sub

sub LoadUserVariables()
	
end sub

sub AddStatusUrls()

	' url$ = "/heehoo"
	m.GetStatusinfoAA = { HandleEvent: m.GetStatusinfo, mVar: m }
	m.GetPlaybackZoneAA = { HandleEvent: m.PlaybackZone, mVar: m }
	m.GetMuteZoneAA = { HandleEvent: m.MuteZone, mVar: m }
	m.RebootPlayerAA = { HandleEvent: m.RebootPlayer, mVar: m }

	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/status", user_data: m.GetStatusinfoAA })

	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/playback", user_data: m.GetPlaybackZoneAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/mute", user_data: m.GetMuteZoneAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/reboot", user_data: m.RebootPlayerAA })
	' m.pluginLocalWebServer.AddPostToFormData({ url_path: "/resume", user_data: m.GetEventinfoAA })


end sub

function RebootPlayer(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()

	for each keys in args
		if lcase(keys) = "reboot" then
			if lcase(args[keys]) then
				e.SetResponseBodyString("a")
				e.SendResponse(200)
				a = RestartApplication()
   				stop
			end if
		end if
	end for 
end function

function PlaybackZone(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()

	print args
	for each keys in args
		' print keys
		' print args[keys]
		if lcase(keys) = "playback" then
			if args.zone <> invalid then
				' print args.zone
				print mVar.bsp.sign
				print "zones: ";mVar.bsp.sign.zonesHSM
				if lcase(args[keys]) = "pause" then
					for each zone in mVar.bsp.sign.zonesHSM
						print "zone name: "; lcase(zone.name$)
						print "args zone name: "; lcase(args.zone)
						' print "zone type: ";type(zone.name$)
						' print "args zone type: ";type(args.zone)
						' print zone.name$ = args.zone
						' print args.zone = zone.name$

						if lcase(zone.name$) = lcase(args.zone) then
							print "Found Zone to Pause: "; args.zone
							if zone.videoplayer <> invalid then zone.videoplayer.Pause()

						end if
					end for
				else if lcase(args[keys]) = "play" then
					for each zone in mVar.bsp.sign.zonesHSM

						if lcase(zone.name$) = lcase(args.zone) then
							print "Found Zone to Play: "; args.zone
							if zone.videoplayer <> invalid then zone.videoplayer.Play()
						end if
						' 	if zone.name = args.zone then
						' 		print "Found Zone to Play: "; args.zone
						' 			if zone.videoplayer <> invalid then zone.videoplayer.Play()
						' 		endif
						' 	endif
					end for
				end if
			else
				if lcase(args[keys]) = "pause" then
					for each zone in mVar.bsp.sign.zonesHSM
						if zone.videoplayer <> invalid then 
							zone.videoplayer.Pause()
							mVar.Playing = false
						end if
					end for
				end if
				if lcase(args[keys]) = "play" then
					for each zone in mVar.bsp.sign.zonesHSM
						if zone.videoplayer <> invalid then 
							zone.videoplayer.Play()
							mVar.Playing = true
						end if
					end for
				end if
			end if
		else if lcase(keys) = "sleep" then
			if lcase(args[keys]) = "true" then
				videoMode = CreateObject("roVideoMode")
				if type(videoMode) = "roVideoMode" then
				  videoMode.SetPowerSaveMode(true)
				  mVar.PowerSave = true
				end if
				videoMode = invalid
			else if lcase(args[keys]) = "false" then
				videoMode = CreateObject("roVideoMode")
				if type(videoMode) = "roVideoMode" then
				  videoMode.SetPowerSaveMode(false)
				  mVar.PowerSave = false
				end if
				videoMode = invalid
			end if
		end if
	end for
	e.SetResponseBodyString("a")
	e.SendResponse(200)
end function

function MuteZone(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()
	print "we muted: ";mVar.Muted

	' print mVar.bsp
	' print "bsp.sign: ";mVar.bsp.sign

	for each keys in args
		print "keys: ";keys
		print "lcasekeys: ";lcase(keys)
		print "argskeys: ";args[keys]
		if lcase(keys) = "mute" then
			print "we muting"
			for each zone in mVar.bsp.sign.zonesHSM
				if type(zone) = "roAssociativeArray" then

					if type(zone.videoPlayer) = "roVideoPlayer" then
						zone.videoPlayer.SetVolume(0)
						if mVar.Muted = false then
							for i% = 0 to 5
								mVar.LastVolume[i%] = zone.videoChannelVolumes[i%]
								zone.videoChannelVolumes[i%] = 0
								mVar.CurrentVolume = 0
							end for
							mVar.Muted = true
						end if
					end if
					if type(zone.audioPlayer) = "roAudioPlayer" then
						zone.audioPlayer.SetVolume(0)
						if mVar.Muted = false then
							for i% = 0 to 5
								mVar.LastVolume[i%] = zone.audioChannelVolumes[i%]
								zone.audioChannelVolumes[i%] = 0
								mVar.CurrentVolume = 0
							end for
							mVar.Muted = true
						end if
					end if
				end if
			end for

			' mVar.bsp.muteaudiooutputs(true, mVar)
			' print mVar.LastVolume
			e.SetResponseBodyString("Muted")
			e.SendResponse(200)
			' print mVar.bsp

		else if lcase(keys) = "unmute" then
			print "we unmuting: ";mVar.Muted
			for each zone in mVar.bsp.sign.zonesHSM
				if type(zone) = "roAssociativeArray" then
					if type(zone.videoPlayer) = "roVideoPlayer" then
						if mVar.Muted = true then
							mVar.CurrentVolume = mVar.LastVolume[0]
							zone.videoPlayer.SetVolume(mVar.LastVolume[0])
							for i% = 0 to 5
								zone.videoChannelVolumes[i%] = mVar.LastVolume[i%]
							end for
							mVar.Muted = false
						end if
					end if
					if type(zone.audioPlayer) = "roAudioPlayer" then
						if mVar.Muted = true then
							mVar.CurrentVolume = mVar.LastVolume[0]
							zone.audioPlayer.SetVolume(mVar.LastVolume[0])
							for i% = 0 to 5
								zone.audioChannelVolumes[i%] = mVar.LastVolume[i%]
							end for
							mVar.Muted = false
						end if
					end if
				end if
			end for
			e.SetResponseBodyString("Unmuted")
			e.SendResponse(200)
		else
			print "we confused"

			e.SetResponseBodyString("a")
			e.SendResponse(200)
		end if

	end for
	e.SetResponseBodyString("a")
	e.SendResponse(200)
end function

function GetStatusinfo(userData as object, e as object) as boolean
	mVar = userData.mVar
	out = {}

	modelObject = CreateObject("roDeviceInfo")
	out.AddReplace("model", modelObject.GetModel())
	out.AddReplace("serialNumber", modelObject.GetDeviceUniqueId())

	out.AddReplace("playing", mVar.Playing)
	out.AddReplace("sleep", mVar.PowerSave)
	out.AddReplace("videomode", mVar.bsp.sign.videomode$)

	out.AddReplace("volume", mVar.CurrentVolume)
	out.AddReplace("muted", mVar.Muted)

	if mVar.bsp.activePresentation <> invalid then
		out.AddReplace("activePresentation", mVar.bsp.activePresentation$) ' TODO check with Ted as active presentation label attribute removed
	end if


	isTheHeaderAddedOK = e.AddResponseHeader("Content-type", "application/json")
	e.SetResponseBodyString(FormatJson(out))
	e.SendResponse(200)
	' print "aa "+registrySection.Read("un")

end function




function StartTimer()

	newTimeout = m.sTime.GetLocalDateTime()
	newTimeout.AddSeconds(5)
	m.readTimer.SetDateTime(newTimeout)
	m.readTimer.Start()

end function


function HandleTimerEvent(origMsg as object, Custom as object) as boolean

	retval = false

	timerIdentity = origMsg.GetSourceIdentity()

	if Custom.readTimer.GetIdentity() = timerIdentity then
		timerIdentity = origMsg.GetSourceIdentity()
	end if


end function


function PluginSendMessage(Pmessage$ as string)

	pluginMessageCmd = CreateObject("roAssociativeArray")
	pluginMessageCmd["EventType"] = "EVENT_PLUGIN_MESSAGE"
	pluginMessageCmd["PluginName"] = "Nodel"
	pluginMessageCmd["PluginMessage"] = Pmessage$
	m.msgPort.PostMessage(pluginMessageCmd)

end function