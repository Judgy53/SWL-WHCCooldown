import com.GameInterface.Game.Dynel;
import com.Utils.Archive;
import com.Utils.Colors;
import com.Utils.ID32;
import com.Utils.LDBFormat;
import com.GameInterface.Game.Character;
import com.GameInterface.DistributedValue;
import com.GameInterface.Utils;
import com.GameInterface.UtilsBase;
import com.GameInterface.VicinitySystem;
import com.GameInterface.WaypointInterface;
import mx.utils.Delegate;

class com.judgy.whcc.WHCCMod {
	private var m_swfRoot:MovieClip; 
	
	public static var m_trackerList:Array;
	private var m_trackedChamp:ID32;
	
	
	private var LockoutsDV:DistributedValue;
	
	public static function main(swfRoot:MovieClip) {
		var s_app = new WHCCMod(swfRoot);
		
		swfRoot.onLoad = function() { s_app.Load(); };
		swfRoot.onUnload = function() { s_app.Unload(); };
		swfRoot.OnModuleActivated = function(config:Archive) { s_app.LoadConfig(config);};
		swfRoot.OnModuleDeactivated = function() { return s_app.SaveConfig(); };
	}
	
	public function WHCCMod(swfRoot:MovieClip) {
		m_swfRoot = swfRoot;
		
		m_trackerList = [];
		m_trackerList.push(CreateTrackerEntry("Kingsmouth Town — Tragedy", 3030, "38190", 0));
		m_trackerList.push(CreateTrackerEntry("The Savage Coast — Groundskeeper Hammond", 3040, "38188", 0));
		m_trackerList.push(CreateTrackerEntry("The Blue Mountain — Max", 3050, "38195", 0));
		
		m_trackerList.push(CreateTrackerEntry("The Scorched Desert — Cursed Soul of Greed", 3090, "38199", 0));
		m_trackerList.push(CreateTrackerEntry("City of the Sun God — Warsmith", 3100, "38184", 0));
		
		m_trackerList.push(CreateTrackerEntry("The Besieged Farmlands — Window-Peeper", 3120, "38194", 0));
		m_trackerList.push(CreateTrackerEntry("The Shadowy Forest — The Grunch", 3130, "38185", 0));
		m_trackerList.push(CreateTrackerEntry("The Carpathian Fangs — Permafrost ", 3140, "38177", 0));
		
		m_trackerList.push(CreateTrackerEntry("Kaidan — The Forgotten", 3070, "38179", 0));
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
			WaypointInterface.SignalPlayfieldChanged.Connect(PlayfieldChanged, this);
			DelayedPlayfieldChanged();
			
			LockoutsDV = DistributedValue.Create("lockoutTimers_window");
			LockoutsDV.SignalChanged.Connect(HookLockoutsWindow, this);
		}
	};
	
	public function OnUnload() {		
		WaypointInterface.SignalPlayfieldChanged.Connect(PlayfieldChanged, this);
		
		VicinitySystem.SignalDynelEnterVicinity.Disconnect(Track, this);
		VicinitySystem.SignalDynelLeaveVicinity.Disconnect(Untrack, this);
		
		LockoutsDV.SignalChanged.Disconnect(HookLockoutsWindow, this);
	}
	
	public function LoadConfig(config:Archive) {
		for (var i in m_trackerList) {
			m_trackerList[i].expiry = config.FindEntry("WHCC_" + m_trackerList[i].playfieldID, 0);
		}
	}
	
	public function SaveConfig() {	
		var archive: Archive = new Archive();
		
		for (var i in m_trackerList) {
			var entry:Object = m_trackerList[i];
			archive.AddEntry("WHCC_" + entry.playfieldID, entry.expiry);
		}
		
		return archive;
	}
	
	
	private function PlayfieldChanged(){
		m_trackedChamp = undefined;
		VicinitySystem.SignalDynelEnterVicinity.Disconnect(Track, this);
		VicinitySystem.SignalDynelLeaveVicinity.Disconnect(Untrack, this);
		
		//Playfield ID seems to always be 0 when signal triggers, adding a small delay fixes it
		setTimeout(Delegate.create(this, DelayedPlayfieldChanged), 100);
		
	}
	
	private function DelayedPlayfieldChanged(){
		if (EnabledPlayfield()){
			//com.GameInterface.UtilsBase.PrintChatText("Playfield Enabled " + Character.GetClientCharacter().GetPlayfieldID());
			VicinitySystem.SignalDynelEnterVicinity.Connect(Track, this);
			VicinitySystem.SignalDynelLeaveVicinity.Connect(Untrack, this);
		}
	}
	
    private function EnabledPlayfield() {
		var playfield = Character.GetClientCharacter().GetPlayfieldID();
		for (var i = 0; i < m_trackerList.length; i++) {
			if (m_trackerList[i].playfieldID == playfield)
				return true;
		}
		return false;
	}
	
	//TRACKING SYSTEM
	private function Track(id:ID32) {
		var dyn:Dynel = Dynel.GetDynel(id);
		//com.GameInterface.UtilsBase.PrintChatText(id.GetType() + " | " + dyn.GetName() + " | " + dyn.GetStat(112));
		if (id.GetType() == 50000) {
			var entry:Object = GetTrackerEntry(dyn);
			if (!entry) return;
			com.GameInterface.UtilsBase.PrintChatText(entry.name + " FOUND o/");
			m_trackedChamp = id;
			
		} else if (id.GetType() == 51322 && dyn.GetStat(112) == 7324711) { // loot bag
			var champDynel:Dynel = Dynel.GetDynel(m_trackedChamp);
			if (champDynel && champDynel.IsDead()) {
				//com.GameInterface.UtilsBase.PrintChatText("LootBag Found and Champ is Dead !");
				StartCooldown(champDynel.GetStat(112));
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
	private function GetWHCList() {
		var arr:Array = new Array();
		
		for (var i = 0; i < m_trackerList.length; i++) {
			var obj = new Object();
			obj.playfieldID = m_trackerList[i].playfieldID;
			obj.name = m_trackerList[i].name;
			obj.expiry = m_trackerList[i].expiry;
			arr.push(obj);
		}
		
		return arr;
	}
	
	private function HookLockoutsWindow(dv:DistributedValue) {
		if (!dv.GetValue()) return;
		var content:MovieClip = _root.lockouttimers.m_Window.m_Content;
		if (!content) { setTimeout(Delegate.create(this, HookLockoutsWindow), 40, dv); }
		else { ApplyHook(content); }
	}
	
	private function ApplyHook(content:MovieClip):Void {
		var proto:MovieClip = content.m_DailyLoginReset;
		var whcs:Array = GetWHCList();
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
}