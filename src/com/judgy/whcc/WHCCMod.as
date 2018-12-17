import com.GameInterface.Game.Dynel;
import com.Utils.Archive;
import com.Utils.Colors;
import com.Utils.ID32;
import com.Utils.LDBFormat;
import com.Utils.WeakList;
import com.GameInterface.Game.Character;
import com.GameInterface.DistributedValue;
import com.GameInterface.Log;
import com.GameInterface.Utils;
import com.GameInterface.UtilsBase;
import com.GameInterface.VicinitySystem;
import com.GameInterface.WaypointInterface;
import mx.utils.Delegate;

class com.judgy.whcc.WHCCMod {
	private var m_swfRoot:MovieClip; 
	
	private var m_trackerList:Array;
	private var m_trackedChamp:ID32;
	
	private var LockoutsDV:DistributedValue;
	private var DebugDV:DistributedValue;
	
	private var m_debugEnabled:Boolean = false;
	
	public static function main(swfRoot:MovieClip) {
		var s_app = new WHCCMod(swfRoot);
		
		swfRoot.onLoad = function() { s_app.Load(); };
		swfRoot.onUnload = function() { s_app.Unload(); };
		swfRoot.OnModuleActivated = function(config:Archive) { s_app.LoadConfig(config);};
		swfRoot.OnModuleDeactivated = function() { return s_app.SaveConfig(); };
	}
	
	public function WHCCMod(swfRoot:MovieClip) {
		m_swfRoot = swfRoot;
    }
	
	private function FillTrackerList() {
		m_trackerList = [];
		m_trackerList.push(CreateTrackerEntry("Kingsmouth Town — Tragedy"					, 3030, "38190", 0));
		m_trackerList.push(CreateTrackerEntry("The Savage Coast — Groundskeeper Hammond"	, 3040, "38188", 0));
		m_trackerList.push(CreateTrackerEntry("The Blue Mountain — Max"						, 3050, "38195", 0));
		
		m_trackerList.push(CreateTrackerEntry("The Scorched Desert — Cursed Soul of Greed"	, 3090, "38199", 0));
		m_trackerList.push(CreateTrackerEntry("City of the Sun God — Warsmith"				, 3100, "38184", 0));
		
		m_trackerList.push(CreateTrackerEntry("The Besieged Farmlands — Window-Peeper"		, 3120, "38194", 0));
		m_trackerList.push(CreateTrackerEntry("The Shadowy Forest — The Grunch"				, 3130, "38185", 0));
		m_trackerList.push(CreateTrackerEntry("The Carpathian Fangs — Permafrost "			, 3140, "38177", 0));
		
		m_trackerList.push(CreateTrackerEntry("Kaidan — The Forgotten"						, 3070, "38179", 0));
	}
	
	private function CreateTrackerEntry(name:String, playfieldID:Number, dynel:String, expiry:Number) {
		var obj:Object = new Object();
		obj.name = name;
		obj.playfieldID = playfieldID;
		obj.dynel = dynel;
		obj.expiry = expiry;
		return obj;
	}
	
	public function Load() {
		if (UtilsBase.GetGameTweak("Seasonal_SWL_Christmas2017")) {
			FillTrackerList();
			
			WaypointInterface.SignalPlayfieldChanged.Connect(PlayfieldChanged, this);
			PlayfieldChanged();
			
			LockoutsDV = DistributedValue.Create("lockoutTimers_window");
			LockoutsDV.SignalChanged.Connect(HookLockoutsWindow, this);
			
			DebugDV = DistributedValue.Create("WHCCooldown_DebugEnabled");
			DebugDV.SignalChanged.Connect(SlotDebugEnabled, this);
		}
	};
	
	public function OnUnload() {
		WaypointInterface.SignalPlayfieldChanged.Connect(PlayfieldChanged, this);
		
		VicinitySystem.SignalDynelEnterVicinity.Disconnect(Track, this);
		VicinitySystem.SignalDynelLeaveVicinity.Disconnect(Untrack, this);
		
		LockoutsDV.SignalChanged.Disconnect(HookLockoutsWindow, this);
		DebugDV.SignalChanged.Disconnect(SlotDebugEnabled, this);
		
		while (m_trackerList.length > 0)
			m_trackerList.shift();
	}
	
	public function LoadConfig(config:Archive) {
		for (var i in m_trackerList) {
			m_trackerList[i].expiry = config.FindEntry("WHCCooldown_" + m_trackerList[i].playfieldID, 0);
		}
		
		DebugDV.SetValue(config.FindEntry("WHCCooldown_DebugEnabled", false));
		SlotDebugEnabled(DebugDV);
	}
	
	public function SaveConfig() {	
		var archive: Archive = new Archive();
		
		for (var i in m_trackerList) {
			var entry:Object = m_trackerList[i];
			archive.AddEntry("WHCCooldown_" + entry.playfieldID, entry.expiry);
		}
		
		archive.AddEntry("WHCCooldown_DebugEnabled", m_debugEnabled);
		
		return archive;
	}
	
	
	private function PlayfieldChanged(){
		m_trackedChamp = undefined;
		VicinitySystem.SignalDynelEnterVicinity.Disconnect(Track, this);
		VicinitySystem.SignalDynelLeaveVicinity.Disconnect(Untrack, this);

		DelayedPlayfieldChanged();		
	}
	
	private function DelayedPlayfieldChanged(){
		var playfield:Number = Character.GetClientCharacter().GetPlayfieldID();
		if (playfield == 0) {
			DebugLog("Playfield ID invalid, delaying signal connect.");
			setTimeout(Delegate.create(this, DelayedPlayfieldChanged), 1000);
			return;
		}
		DebugLog("Playfield ID Valid : " + playfield);
		if (EnabledPlayfield(playfield)){
			DebugLog("Playfield Entry found. WHC tracking enabled");
			VicinitySystem.SignalDynelEnterVicinity.Connect(Track, this);
			VicinitySystem.SignalDynelLeaveVicinity.Connect(Untrack, this);
			//kickstartTracking(); //has a huge chance to make the game crash.
		} else {
			DebugLog("Playfield Entry not found. WHC tracking disabled");
		}
	}
	
    private function EnabledPlayfield(playfield:Number) {
		for (var i = 0; i < m_trackerList.length; i++) {
			if (m_trackerList[i].playfieldID == playfield)
				return true;
		}
		return false;
	}
	
	private function kickstartTracking() {
		var list:WeakList = Dynel.s_DynelList;
		for (var i = 0; i < list.GetLength(); i++) {
			var dyn:Dynel = list.GetObject(i);
			Track(dyn.GetID());
		}
	}
	
	//TRACKING SYSTEM
	private function Track(id:ID32) {
		var dyn:Dynel = Dynel.GetDynel(id);
		//com.GameInterface.UtilsBase.PrintChatText(id.GetType() + " | " + dyn.GetName() + " | " + dyn.GetStat(112));
		if (id.GetType() == 50000) {
			var entry:Object = GetTrackerEntry(dyn);
			if (!entry) return;
			DebugLog("WHC Found and tracked : \"" + entry.name + "\"");
			m_trackedChamp = id;
			
		} else if (id.GetType() == 51322 && dyn.GetStat(112) == 7324711) { // loot bag
			var champDynel:Dynel = Dynel.GetDynel(m_trackedChamp);
			if (champDynel && champDynel.IsDead()) {
				DebugLog("LootBag Found and WHC is Dead. Starting cooldown.");
				StartCooldown(champDynel.GetStat(112));
			} else {
				DebugLog("LootBag Found but WHC tracking went wrong. Cooldown not started");
			}
		}
	}
	
	private function Untrack(id:ID32) {
		if (m_trackedChamp == undefined) return;
		if (id.Equal(m_trackedChamp))
			m_trackedChamp = undefined;
	}
	
	private function GetTrackerEntry(dyn:Dynel) {
		for (var i in m_trackerList) {
			if (m_trackerList[i].dynel == string(dyn.GetStat(112)))
				return m_trackerList[i];
		}
		return undefined;
	}
	
	private function StartCooldown(dynel:Number) {
		var time:Number = Utils.GetServerSyncedTime();
		var cooldownEnd:Number = time + 18 * 60 * 60;
		
		for (var i in m_trackerList) {
			if (m_trackerList[i].dynel == dynel) {
				m_trackerList[i].expiry = cooldownEnd;
			}
		}
	}
	
	
	
	//UI STUFF BELOW (HEAVILY "INSPIRED" FROM CLOCKWATCHER)	
	private function HookLockoutsWindow(dv:DistributedValue) {
		if (!dv.GetValue()) return;
		var content:MovieClip = _root.lockouttimers.m_Window.m_Content;
		if (!content) { setTimeout(Delegate.create(this, HookLockoutsWindow), 40, dv); }
		else { ApplyHook(content); }
	}
	
	private function ApplyHook(content:MovieClip):Void {
		DebugLog("Lockout Window Hook Started");
		if (content.m_WHCS != undefined || content.UpdateWHCS != undefined) {
			DebugLog("Lockout Window Hook Failed - Hook already applied");
			return;
		}
		var proto:MovieClip = content.m_DailyLoginReset;
		var whcs:Array = m_trackerList;
		content.m_WHCS = new Array();
		for (var i:Number = 0; i < whcs.length; ++i) {
			var clip:MovieClip = proto.duplicateMovieClip("m_WHC" + whcs[i].playfieldID, content.getNextHighestDepth());
			clip._x = proto._x + proto._width + 20;
			clip._y = proto._y + (proto._height * i);
			clip.m_Name.text = whcs[i].name
			clip.m_Expiry = whcs[i].expiry;
			clip.UpdateExpiry = UpdateExpiry;
			content.m_WHCS.push(clip);
		}
		content.SignalSizeChanged.Emit();

		content.UpdateWHCS = ContentUpdateWHCS;
		content.ClearTimeInterval = proto.ClearTimeInterval;
		content.onUnload = onContentUnload;
		content.m_TimeIntervalWHCS = setInterval(content, "UpdateWHCS", 1000);
		content.UpdateWHCS();
		DebugLog("Lockout Window Hook Done");
	}
	
	private function UpdateExpiry(time:Number) {
		var target:Object = this;
		var timeStr:String = FormatRemainingTime(target.m_Expiry, time);
		if (timeStr)
			target.m_Lockout.text = timeStr;
		else {
			target.m_Lockout.textColor = Colors.e_ColorGreen;
			target.m_Lockout.text = LDBFormat.LDBGetText("MiscGUI", "LockoutTimers_Available");
			return true;
		}
		return false;
	}
	
	public static function FormatRemainingTime(expiry:Number, time:Number) {
		if (!expiry) { return undefined; }
		var remaining:Number = Math.floor(expiry - time);
		if (remaining <= 0) { return undefined; }
		var hours:String = String(Math.floor(remaining / 3600));
		if (hours.length == 1) { hours = "0" + hours; }
		var minutes:String = String(Math.floor((remaining / 60) % 60));
		if (minutes.length == 1) { minutes = "0" + minutes; }
		var seconds:String = String(Math.floor(remaining % 60));
		if (seconds.length == 1) { seconds = "0" + seconds; }
		return hours + ":" + minutes + ":" + seconds;
	}
	
	private function onContentUnload():Void {
		var target:Object = this;
		target.ClearTimeInterval();
		target.super.onUnload();
	}

	private function ContentUpdateWHCS():Void {
		var target:Object = this;
		var allClear:Boolean = true;
		var time:Number = Utils.GetServerSyncedTime();
		for (var i:Number = 0; i < target.m_WHCS.length; ++i) {
			allClear = target.m_WHCS[i].UpdateExpiry(time) && allClear;
		}
		if (allClear) { target.ClearTimeInterval(); }
	}
	
	private function SlotDebugEnabled(dv:DistributedValue) {
		if (DebugDV.GetValue()) {
			m_debugEnabled = true;
			DebugLog("Debug Enabled");
		} else {
			DebugLog("Debug Disabled");
			m_debugEnabled = false;
		}
	}
	
	private function DebugLog(str:String) {
		if (m_debugEnabled) {
			UtilsBase.PrintChatText("[WHCC] " + str);
			Log.Error("[WHCC]", str);
		}
	}
}