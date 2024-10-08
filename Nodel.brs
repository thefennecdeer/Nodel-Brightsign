' 23/09/2024
' Nodel Control Script v2.0
' Troy Takac (troy@fennecdeer.com)

function Nodel_Initialize(msgPort as object, userVariables as object, bsp as object)
	Nodel = newNodel(msgPort, userVariables, bsp)
	return Nodel
end function

function newNodel(msgPort as object, userVariables as object, bsp as object)
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
	s.SetVolZone = SetVolZone
	s.RebootPlayer = RebootPlayer
	s.DefaultsPlayer = DefaultsPlayer
	
	s.Subscribe = Subscribe
	s.CurrentSubscribers = {}
	s.PlaybackSingleZone = PlaybackSingleZone
	s.SleepSingleZone = SleepSingleZone
	s.SetVolSingleZone = SetVolSingleZone
	s.LoadRegistry = LoadRegistry 

	s.Registry = CreateObject("roRegistrySection", "Nodel")
	
	videoMode = CreateObject("roVideoMode")
		if type(videoMode) = "roVideoMode" then
			s.SleepSingleZone("true", videoMode)
		end if

	s.AddStatusUrls = AddStatusUrls
	s.HandleHTTPEventPlugin = HandleHTTPEventPlugin
	s.nc = CreateObject("roNetworkConfiguration", 0)
	s.PlayerIP = ""
	s.currentConfig = ""
	s.currentConfig = s.nc.GetCurrentConfig()
	if s.currentConfig <> invalid then
		s.PlayerIP = s.currentConfig.ip4_address
	end if

	s.Storage = "SD:"
	s.Path = "/"
	s.vmPlugin = CreateObject("roVideoMode")
	s.AddHttpHandlers()

	reg = CreateObject("roRegistrySection", "networking")
	reg.write("ssh","22")
	n=CreateObject("roNetworkConfiguration", 0)
	n.SetLoginPassword("nodel")
	n.Apply()
	reg.flush()
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
		screenShotParam["filename"] = m.Storage + m.Path + "mySnap/LastSnapshot.jpg"
		screenShotParam["width"] = m.vmPlugin.GetResX()
		screenShotParam["height"] = m.vmPlugin.GetResY()
		screenShotParam["filetype"] = "JPEG"
		screenShotParam["quality"] = 25
		screenShotParam["async"] = 0
		screenShotTaken = m.vmPlugin.Screenshot(screenShotParam)
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
	if type(event) = "roVideoEvent" then
		print "event: ";event
		if event = 3 then
			if m.FirstCheck = true then
				m.LoadRegistry()
				m.FirstCheck = false
			end if
		end if
	else if type(event) = "roTimerEvent" then
		retval = HandleTimerEvent(event, m)
	else if type(event) = "roAssociativeArray" then
		if type(event["EventType"]) = "roString"
			if event["EventType"] = "EVENT_PLUGIN_MESSAGE" then
				if event["PluginName"] = "Nodel" then
					pluginMessage$ = event["PluginMessage"]
				end if
			else if event["EventType"] = "SEND_PLUGIN_MESSAGE" then
				if event["PluginName"] = "Nodel" then
					pluginMessage$ = event["PluginMessage"]
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
	m.pluginLocalWebServer = CreateObject("roHttpServer", { port: 8081 })
	m.pluginLocalWebServer.SetPort(m.msgPort)
	m.AddStatusUrls()
end sub

sub LoadRegistry()
	print "Loading Registry"
	if m.Registry.Exists("powersave") then
		if m.Registry.Read("powersave") = "false" then
			videoMode = CreateObject("roVideoMode")
			if type(videoMode) = "roVideoMode" then
				m.SleepSingleZone("false", videoMode)
			end if
		end if
	else
		m.Registry.Write("powersave", "false")
		videoMode = CreateObject("roVideoMode")
		if type(videoMode) = "roVideoMode" then
			m.SleepSingleZone("false", videoMode)
		end if
	end if

	if m.Registry.Exists("playing") then
		if m.Registry.Read("playing") = "false" then
			for each zone in m.bsp.sign.zonesHSM
				if zone.videoplayer <> invalid then 
					m.PlaybackSingleZone("pause", zone)
				end if
			end for
		end if
	else
		m.Registry.Write("playing", "true")
	end if

	if m.Registry.Exists("currentvolume") then
		print "Current Volume found"
	else
		m.Registry.Write("currentvolume", "100")
	end if

	if m.Registry.Exists("subscribers") then
		m.CurrentSubscribers = ParseJson(m.Registry.Read("subscribers")) 
		print "Subscriber List Found!"
	else
		m.Registry.Write("subscribers", FormatJson({active:[]}))
	end if

	if m.Registry.Exists("lastvolume") then
		print "Last Volume found"
	else
		print "Last Volume not found"
		m.Registry.Write("lastvolume", "100")
	end if

	if m.Registry.Exists("muted") then
		if m.Registry.Read("muted") = "true" then
			for each zone in m.bsp.sign.zonesHSM
				if type(zone) = "roAssociativeArray" then
					if type(zone.videoPlayer) = "roVideoPlayer" then
						m.SetVolSingleZone("0", zone)
					end if
				end if
				if type(zone) = "roAssociativeArray" then
					if type(zone.audioPlayer) = "roAudioPlayer" then
						m.SetVolSingleZone("0", zone)
					end if
				end if
			end for
		else
			for each zone in m.bsp.sign.zonesHSM
				if type(zone) = "roAssociativeArray" then
					if type(zone.videoPlayer) = "roVideoPlayer" then
						m.SetVolSingleZone(m.Registry.Read("currentvolume"), zone)
					end if
				end if
				if type(zone) = "roAssociativeArray" then
					if type(zone.audioPlayer) = "roAudioPlayer" then
						m.SetVolSingleZone(m.Registry.Read("currentvolume"), zone)
					end if
				end if
			end for
		end if
	else
		print "No Registry Data"
		m.Registry.Write("muted", "false")
		m.Registry.Write("currentvolume", "100")
		m.Registry.Write("lastvolume", "100")
		m.Registry.Write("powersave", "false")
		m.Registry.Write("playing", "true")

	end if
	m.Registry.Flush()
end sub

sub AddStatusUrls()
	m.GetStatusinfoAA = { HandleEvent: m.GetStatusinfo, mVar: m }
	m.GetPlaybackZoneAA = { HandleEvent: m.PlaybackZone, mVar: m }
	m.GetMuteZoneAA = { HandleEvent: m.MuteZone, mVar: m }
	m.SetVolZoneAA = { HandleEvent: m.SetVolZone, mVar: m }
	m.RebootPlayerAA = { HandleEvent: m.RebootPlayer, mVar: m }
	m.DefaultsPlayerAA = { HandleEvent: m.DefaultsPlayer, mVar: m }
	m.SubscribeAA = { HandleEvent: m.Subscribe, mVar: m }
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/status", user_data: m.GetStatusinfoAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/playback", user_data: m.GetPlaybackZoneAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/mute", user_data: m.GetMuteZoneAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/volume", user_data: m.SetVolZoneAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/reboot", user_data: m.RebootPlayerAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/default", user_data: m.DefaultsPlayerAA })
	m.pluginLocalWebServer.AddGetFromEvent({ url_path: "/subscribe", user_data: m.SubscribeAA })
end sub

function RebootPlayer(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()

	for each keys in args
		if lcase(keys) = "reboot" then
			e.SetResponseBodyString("Blank")
			e.SendResponse(200)
			RebootSystem()
   			stop
			
		end if
	end for 
end function

function DefaultsPlayer(userData as object, e as object) as boolean
	mVar = userData.mVar
	mVar.Registry.Write("muted", "false")
	mVar.Registry.Write("currentvolume", "100")
	mVar.Registry.Write("lastvolume", "100")
	mVar.Registry.Write("powersave", "false")
	mVar.Registry.Write("playing", "true")
	mVar.Registry.Write("currentSubscribers", "{'active':[]}")
	e.SetResponseBodyString("Blank")
	e.SendResponse(200)
end function

function PlaybackZone(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()
	print args
	for each keys in args
		if lcase(keys) = "playback" then
			if args.zone <> invalid then
				if lcase(args[keys]) = "pause" then
					for each zone in mVar.bsp.sign.zonesHSM
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
					end for
				end if
			else
				if lcase(args[keys]) = "pause" then
					for each zone in mVar.bsp.sign.zonesHSM
						if zone.videoplayer <> invalid then 
							mVar.PlaybackSingleZone("pause", zone)
							mVar.Registry.Write("playing", "false")
						end if
					end for
				end if
				if lcase(args[keys]) = "play" then
					for each zone in mVar.bsp.sign.zonesHSM
						if zone.videoplayer <> invalid then 
							videoMode = CreateObject("roVideoMode")
							if mVar.Registry.Read("powersave") = "false" then
								mVar.SleepSingleZone("false", videoMode)
								mVar.Registry.Write("powersave", "false")
							end if
							mVar.PlaybackSingleZone("play", zone)
							mVar.Registry.Write("playing", "true")
						end if
					end for
				end if
			end if
		else if lcase(keys) = "sleep" then
			if lcase(args[keys]) = "true" then
				videoMode = CreateObject("roVideoMode")
				if type(videoMode) = "roVideoMode" then
					mVar.SleepSingleZone("true", videoMode)
					mVar.Registry.Write("powersave", "true")
					for each zone in mVar.bsp.sign.zonesHSM
						if type(zone) = "roAssociativeArray" then
							mVar.Registry.Write("lastvolume", mVar.Registry.Read("currentvolume"))
							mVar.SetVolSingleZone("0", zone)
							if zone.videoplayer <> invalid then 
								mVar.PlaybackSingleZone("pause", zone)
								mVar.Registry.Write("playing", "false")
							end if
						end if
					end for
				end if
				videoMode = invalid
			else if lcase(args[keys]) = "false" then
				videoMode = CreateObject("roVideoMode")
				if type(videoMode) = "roVideoMode" then
					mVar.SleepSingleZone("false", videoMode)
					mVar.Registry.Write("powersave", "false")
					for each zone in mVar.bsp.sign.zonesHSM
						if type(zone) = "roAssociativeArray" then
							mVar.SetVolSingleZone( mVar.Registry.Read("lastvolume"), zone)
							if zone.videoplayer <> invalid then 
								mVar.PlaybackSingleZone("play", zone)
								mVar.Registry.Write("playing", "true")
							end if
						end if
					end for
				end if
				videoMode = invalid
			end if
		end if
	end for
	e.SetResponseBodyString("Blank")
	e.SendResponse(200)
end function

function PlaybackSingleZone(state as object, zone as object) as boolean
	if state = "play" then
		zone.videoplayer.Play()
	else if state = "pause" then	
		zone.videoplayer.Pause()
	end if
end function

function SleepSingleZone(state as object, videoMode as object) as boolean
	if state = "true" then
		videoMode.SetPowerSaveMode(true)
	else if state = "false" then	
		videoMode.SetPowerSaveMode(false)
	end if
end function

function SetVolSingleZone(volume as string, zone as object) as boolean
	print "Volume: ";(volume.ToInt())
	zone.videoPlayer.SetVolume(volume.ToInt())
	for i% = 0 to 5
		zone.videoChannelVolumes[i%] = volume.ToInt()
		m.Registry.Write("currentvolume", volume)
	end for
	m.Registry.Flush()
end function

function SetVolZone(userData as object, e as object) as boolean
	mVar = userData.mVar
	for each keys in args
		for each zone in mVar.bsp.sign.zonesHSM
			if type(zone) = "roAssociativeArray" then
				if mVar.Registry.Read("muted") = "true" then
					if mVar.Registry.Read("powersave") = "false" then
						mVar.Registry.Write("lastvolume", volume)
					else
						mVar.SetVolSingleZone(keys, zone)
					end if
				else
					mVar.SetVolSingleZone(keys, zone)
				end if
			end if
		end for
	end for
	e.SetResponseBodyString("Muted")
	e.SendResponse(200)
end function

function MuteZone(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()
	for each keys in args
		if lcase(keys) = "mute" then
			for each zone in mVar.bsp.sign.zonesHSM
				if type(zone) = "roAssociativeArray" then
					if type(zone.videoPlayer) = "roVideoPlayer" then
						if mVar.Registry.Read("muted") <> "true" then
							mVar.Registry.Write("lastvolume", zone.videoChannelVolumes[0].tostr())
							mVar.SetVolSingleZone("0", zone)
							mVar.Registry.Write("muted", "true")
						end if
					end if
					if type(zone.audioPlayer) = "roAudioPlayer" then
						if mVar.Registry.Read("muted") <> "true" then
							mVar.Registry.Write("lastvolume", zone.audioChannelVolumes[0].tostr())
							mVar.SetVolSingleZone("0", zone)
							mVar.Registry.Write("muted", "true")
						end if
					end if
				end if
			end for
			e.SetResponseBodyString("Muted")
			e.SendResponse(200)
			mVar.Registry.Flush()
		else if lcase(keys) = "unmute" then
			for each zone in mVar.bsp.sign.zonesHSM
				if type(zone) = "roAssociativeArray" then
					if type(zone.videoPlayer) = "roVideoPlayer" then
						if mVar.Registry.Read("muted") <> "false" then
							mVar.SetVolSingleZone(mVar.Registry.Read("lastvolume"), zone)
							mVar.Registry.Write("muted", "false") 
						end if
					end if
					if type(zone.audioPlayer) = "roAudioPlayer" then
						if mVar.Registry.Read("muted") <> "false" then
							mVar.SetVolSingleZone(mVar.Registry.Read("lastvolume"), zone)
							mVar.Registry.Write("muted", "false") 
						end if
					end if
				end if
			end for
			e.SetResponseBodyString("Unmuted")
			e.SendResponse(200)
			mVar.Registry.Flush()
		else
			e.SetResponseBodyString("Blank")
			e.SendResponse(200)
		end if
	end for
	e.SetResponseBodyString("Blank")
	e.SendResponse(200)
end function

function GetStatusinfo(userData as object, e as object) as boolean
	mVar = userData.mVar
	out = {}
	modelObject = CreateObject("roDeviceInfo")
	out.AddReplace("model", modelObject.GetModel())
	out.AddReplace("serialNumber", modelObject.GetDeviceUniqueId())
	out.AddReplace("playing", mVar.Registry.Read("playing"))
	out.AddReplace("sleep", mVar.Registry.Read("powersave"))
	out.AddReplace("videomode", mVar.bsp.sign.videomode$)
	out.AddReplace("volume", mVar.Registry.Read("currentvolume"))
	out.AddReplace("muted", mVar.Registry.Read("muted"))
	if mVar.bsp.activePresentation <> invalid then
		out.AddReplace("activePresentation", mVar.bsp.activePresentation$) 
	end if
	isTheHeaderAddedOK = e.AddResponseHeader("Content-type", "application/json")
	e.SetResponseBodyString(FormatJson(out))
	e.SendResponse(200)
end function


function Subscribe(userData as object, e as object) as boolean
	mVar = userData.mVar
	args = e.GetRequestParams()
	tempaddress = ""
	tempport = ""
	for each keys in args
		if lcase(keys) = "address" then
			tempaddress = args[keys]
		else if lcase(keys) = "port"
			tempport = args[keys]
		end if
	end for

	print "address: ";tempaddress
	print "port: ";tempport

	if tempaddress <> "" and tempport <> "" then
		tempfull = tempaddress + ":" + tempport
		print "full: ";tempfull

		for each keys in mVar.CurrentSubscribers
			if keys = tempfull then
				e.SetResponseBodyString("Already Subscribed!")
				e.SendResponse(200)
				stop
			end if
		end for
		
		mVar.CurrentSubscribers.active.push(tempfull)
		mVar.Registry.Write("subscribers", FormatJson(mVar.CurrentSubscribers))
		print "final json: ";FormatJson(mVar.CurrentSubscribers)

		e.SetResponseBodyString("Added!")
		e.SendResponse(200)
	else
		e.SetResponseBodyString("incorrect formatting!")
		e.SendResponse(400)
	end if	

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
