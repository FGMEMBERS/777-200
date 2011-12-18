#############################################################################
# 777 Autopilot Flight Director System
# Syd Adams
#
# speed modes: THR,THR REF, IDLE,HOLD,SPD;
# roll modes : TO/GA,HDG SEL,HDG HOLD, LNAV,LOC,ROLLOUT,TRK SEL, TRK HOLD,ATT;
# pitch modes: TO/GA,ALT,V/S,VNAV PTH,VNAV SPD,VNAV ALT,G/S,FLARE,FLCH SPD,FPA;
# FPA range  : -9.9 ~ 9.9 degrees
# VS range   : -8000 ~ 6000
# ALT range  : 0 ~ 50,000
# KIAS range : 100 ~ 399
# MACH range : 0.40 ~ 0.95
#
#############################################################################

#Usage : var afds = AFDS.new();

var copilot = func(msg) { setprop("/sim/messages/copilot",msg);}

var AFDS = {
	new : func{
		var m = {parents:[AFDS]};

		m.spd_list=["","THR","THR REF","HOLD","IDLE","SPD"];

		m.roll_list=["","HDG SEL","HDG HOLD","LNAV","LOC","ROLLOUT",
		"TRK SEL","TRK HOLD","ATT","TO/GA"];

		m.pitch_list=["","ALT","V/S","VNAV PTH","VNAV SPD",
		"VNAV ALT","G/S","FLARE","FLCH SPD","FPA","TO/GA"];

		m.step=0;

		m.AFDS_node = props.globals.getNode("instrumentation/afds",1);
		m.AFDS_inputs = m.AFDS_node.getNode("inputs",1);
		m.AFDS_apmodes = m.AFDS_node.getNode("ap-modes",1);
		m.AFDS_settings = m.AFDS_node.getNode("settings",1);
		m.AP_settings = props.globals.getNode("autopilot/settings",1);

		m.AP = m.AFDS_inputs.initNode("AP",0,"BOOL");
		m.AP_disengaged = m.AFDS_inputs.initNode("AP-disengage",0,"BOOL");
		m.AP_passive = props.globals.initNode("autopilot/locks/passive-mode",1,"BOOL");
		m.AP_pitch_engaged = props.globals.initNode("autopilot/locks/pitch-engaged",1,"BOOL");
		m.AP_roll_engaged = props.globals.initNode("autopilot/locks/roll-engaged",1,"BOOL");

		m.FD = m.AFDS_inputs.initNode("FD",0,"BOOL");
		m.at1 = m.AFDS_inputs.initNode("at-armed[0]",0,"BOOL");
		m.at2 = m.AFDS_inputs.initNode("at-armed[1]",0,"BOOL");
		m.alt_knob = m.AFDS_inputs.initNode("alt-knob",0,"BOOL");
		m.autothrottle_mode = m.AFDS_inputs.initNode("autothrottle-index",0,"INT");
		m.lateral_mode = m.AFDS_inputs.initNode("lateral-index",0,"INT");
		m.vertical_mode = m.AFDS_inputs.initNode("vertical-index",0,"INT");
		m.gs_armed = m.AFDS_inputs.initNode("gs-armed",0,"BOOL");
		m.loc_armed = m.AFDS_inputs.initNode("loc-armed",0,"BOOL");
		m.vor_armed = m.AFDS_inputs.initNode("vor-armed",0,"BOOL");
		m.lnav_armed = m.AFDS_inputs.initNode("lnav-armed",0,"BOOL");
		m.vnav_armed = m.AFDS_inputs.initNode("vnav-armed",0,"BOOL");
		m.rollout_armed = m.AFDS_inputs.initNode("rollout-armed",0,"BOOL");
		m.flare_armed = m.AFDS_inputs.initNode("flare-armed",0,"BOOL");
		m.ias_mach_selected = m.AFDS_inputs.initNode("ias-mach-selected",0,"BOOL");
		m.hdg_trk_selected = m.AFDS_inputs.initNode("hdg-trk-selected",0,"BOOL");
		m.vs_fpa_selected = m.AFDS_inputs.initNode("vs-fpa-selected",0,"BOOL");
		m.bank_switch = m.AFDS_inputs.initNode("bank-limit-switch",0,"INT");

		m.ias_setting = m.AP_settings.initNode("target-speed-kt",200);# 100 - 399 #
		m.mach_setting = m.AP_settings.initNode("target-speed-mach",0.40);# 0.40 - 0.95 #
		m.vs_setting = m.AP_settings.initNode("vertical-speed-fpm",0); # -8000 to +6000 #
		m.hdg_setting = m.AP_settings.initNode("heading-bug-deg",360,"INT"); # 1 to 360
		m.fpa_setting = m.AP_settings.initNode("flight-path-angle",0); # -9.9 to 9.9 #
		m.alt_setting = m.AP_settings.initNode("counter-set-altitude-ft",10000,"DOUBLE");
		m.target_alt = m.AP_settings.initNode("actual-target-altitude-ft",10000,"DOUBLE");
		m.auto_brake_setting = m.AP_settings.initNode("autobrake",0.000,"DOUBLE");

		m.trk_setting = m.AFDS_settings.initNode("trk",0,"INT");
		m.vs_display = m.AFDS_settings.initNode("vs-display",0);
		m.fpa_display = m.AFDS_settings.initNode("fpa-display",0);
		m.bank_min = m.AFDS_settings.initNode("bank-min",-25);
		m.bank_max = m.AFDS_settings.initNode("bank-max",25);
		m.pitch_min = m.AFDS_settings.initNode("pitch-min",-10);
		m.pitch_max = m.AFDS_settings.initNode("pitch-max",15);
		m.vnav_alt = m.AFDS_settings.initNode("vnav-alt",35000);
		m.auto_popup = m.AFDS_settings.initNode("auto-pop-up",0,"BOOL");

		m.AP_roll_mode = m.AFDS_apmodes.initNode("roll-mode","TO/GA");
		m.AP_roll_arm = m.AFDS_apmodes.initNode("roll-mode-arm"," ");
		m.AP_pitch_mode = m.AFDS_apmodes.initNode("pitch-mode","TO/GA");
		m.AP_pitch_arm = m.AFDS_apmodes.initNode("pitch-mode-arm"," ");
		m.AP_speed_mode = m.AFDS_apmodes.initNode("speed-mode","");
		m.AP_annun = m.AFDS_apmodes.initNode("mode-annunciator"," ");

		m.APl = setlistener(m.AP, func m.setAP(),0,0);
		m.APdisl = setlistener(m.AP_disengaged, func m.setAP(),0,0);
		m.Lbank = setlistener(m.bank_switch, func m.setbank(),0,0);
		m.LTMode = setlistener(m.autothrottle_mode, func m.updateATMode(),0,0);
		m.WpChanged = setlistener(props.globals.getNode("/autopilot/route-manager/wp/id",1), func m.wpChanged(),0,0);
		m.RmDisabled = setlistener(props.globals.getNode("/autopilot/route-manager/active",1), func m.wpChanged(),0,0);
		return m;
	},

####  Inputs   ####
###################
	input : func(mode,btn)
	{
		if(getprop("/systems/electrical/outputs/avionics"))
		{
			current_alt = getprop("instrumentation/altimeter/indicated-altitude-ft");
			if(mode==0)
			{
				# horizontal AP controls
				if(btn == 1)		# Heading Sel button
				{
					if(getprop("position/gear-agl-ft") < 50)
					{
						btn = me.lateral_mode.getValue();
					}
				}
				elsif(btn == 2)		# Heading Hold button
				{
					# set target to current magnetic heading
					var tgtHdg = int(getprop("orientation/heading-magnetic-deg") + 0.50);
					if (tgtHdg==0) tgtHdg=360;
					me.hdg_setting.setValue(tgtHdg);
					if(getprop("position/gear-agl-ft") < 50)
					{
						btn = me.lateral_mode.getValue();
					}
					else
					{
						btn = 1;    # Heading sel
					}
				}
				elsif(btn==3)		# LNAV button
				{
					if ((!getprop("/autopilot/route-manager/active"))or
						(getprop("/autopilot/route-manager/current-wp")<0)or
						(getprop("/autopilot/route-manager/wp/id")==""))
					{
						# Oops, route manager isn't active. Keep current mode.
						btn = me.lateral_mode.getValue();
						copilot("Captain, LNAV doesn't engage. We forgot to program or activate the route manager!");
					}
					else
					{
						if(me.lateral_mode.getValue() == 3)		# Current mode is LNAV
						{
							# set target to current magnetic heading
							var tgtHdg = int(getprop("orientation/heading-magnetic-deg") + 0.50);
							if (tgtHdg==0) tgtHdg=360;
							me.hdg_setting.setValue(tgtHdg);
							btn = 1;	# Heading sel
						}
						elsif(me.lnav_armed.getValue())
						{	# LNAV armed then disarm
							me.lnav_armed.setValue(0);
							btn = me.lateral_mode.getValue();
						}
						else
						{	# LNAV arm
							me.lnav_armed.setValue(1);
							btn = me.lateral_mode.getValue();
						}
					}
				}
				me.lateral_mode.setValue(btn);
			}
			elsif(mode==1)
			{
				# vertical AP controls
				if (btn==1)
				{
					# hold current altitude
					if(me.AP.getValue() or me.FD.getValue())
					{
						var alt = int((current_alt+50)/100)*100;
						me.target_alt.setValue(alt);
						me.autothrottle_mode.setValue(5);	# A/T SPD
					}
					else
					{
						btn = 0;
					}
				}
				if(btn==2)
				{
					# hold current vertical speed
					var vs = getprop("instrumentation/inst-vertical-speed-indicator/indicated-speed-fpm");
					vs = int(vs/100)*100;
					if (vs<-8000) vs = -8000;
					if (vs>6000) vs = 6000;
					me.vs_setting.setValue(vs);
					if(vs == 0)
					{
						me.target_alt.setValue(current_alt);
					}
					else
					{
						me.target_alt.setValue(me.alt_setting.getValue());
					}
					me.autothrottle_mode.setValue(5);	# A/T SPD
				}
				elsif(btn == 255)
				{
					if(me.vs_setting.getValue() == 0)
					{
						me.target_alt.setValue(current_alt);
					}
					else
					{
						me.target_alt.setValue(me.alt_setting.getValue());
					}
					btn = 2;
				}
				if(btn==5)		# VNAV
				{
					if ((!getprop("/autopilot/route-manager/active"))or
						(getprop("/autopilot/route-manager/current-wp")<0)or
						(getprop("/autopilot/route-manager/wp/id")==""))
					{
						# Oops, route manager isn't active. Keep current mode.
						btn = me.vertical_mode.getValue();
						copilot("Captain, VNAV doesn't engage. We forgot to program or activate the route manager!");
					}
					else
					{
						vnav_mode = me.vertical_mode.getValue();
						if(vnav_mode == 3)			# Current mode is VNAV PTH
						{
						}
						elsif(vnav_mode == 4)		# Current mode is VNAV SPD
						{
						}
						elsif(vnav_mode == 5)		# Current mode is VNAV ALT
						{
						}
						elsif(me.vnav_armed.getValue())
						{	# VNAV armed then disarm
							me.vnav_armed.setValue(0);
							btn = vnav_mode;
						}
						else
						{	# VNAV arm
							me.vnav_armed.setValue(1);
							btn = vnav_mode;
						}
					}
				}
				if(btn==8)		# FLCH SPD
				{
					# change flight level
					if(((current_alt
						- getprop("autopilot/internal/airport-height")) < 400)
						or (me.at1.getValue() == 0) or (me.at2.getValue() == 0))
					{
						btn = 0;
					}
					elsif(current_alt < me.alt_setting.getValue())
					{
						me.autothrottle_mode.setValue(1);	# A/T THR
					}
					else
					{
						me.autothrottle_mode.setValue(4);	# A/T IDLE
					}
					alt = me.alt_setting.getValue();
					me.target_alt.setValue(alt);
				}
				me.vertical_mode.setValue(btn);
			}
			elsif(mode == 2)
			{
				# throttle AP controls
				if(me.autothrottle_mode.getValue() != 0
					or (me.at1.getValue() == 0) or (me.at2.getValue() == 0))
				{
					btn = 0;
				}
				elsif(btn == 2)		# TOGA
				{
					if((getprop("instrumentation/airspeed-indicator/indicated-speed-kt") > 50)
						or (getprop("/controls/flight/flaps") == 0))
					{
						btn = 0;
					}
					me.auto_popup.setValue(1);
				}
				elsif((current_alt
						- getprop("autopilot/internal/airport-height")) < 400)
				{
					btn=0;
					copilot("Captain, auto-throttle won't engage below 400ft.");
				}
				me.autothrottle_mode.setValue(btn);
			}
			elsif(mode==3)	#FD, LOC or G/S button
			{
				if(btn == 2)	# FD button toggle
				{
					if(me.FD.getValue())
					{
						if(getprop("gear/gear[1]/wow"))
						{
							me.lateral_mode.setValue(9);		# TOGA
							me.vertical_mode.setValue(10);		# TOGA
						}
					}
					else
					{
						me.lateral_mode.setValue(0);		# Clear
						me.vertical_mode.setValue(0);		# Clear
					}
				}
				elsif(btn == 3)	# AP button toggle
				{
					if(!me.AP.getValue())
					{
						me.rollout_armed.setValue(0);
						me.flare_armed.setValue(0);
						me.loc_armed.setValue(0);			# Disarm
						me.gs_armed.setValue(0);			# Disarm
						if(!me.FD.getValue())
						{
							me.lateral_mode.setValue(0);		# NO MODE
							me.vertical_mode.setValue(0);		# NO MODE
						}
						else
						{
							me.lateral_mode.setValue(2);		# HDG HOLD
							me.vertical_mode.setValue(1);		# ALT
						}
					}
					else
					{
						if(!me.FD.getValue())
						{
							current_bank = getprop("orientation/roll-deg");
							if(current_bank > 5)
							{
								setprop("autopilot/internal/target-roll-deg", current_bank);
								me.lateral_mode.setValue(8);		# ATT
							}
							else
							{
								# set target to current magnetic heading
								tgtHdg = int(getprop("orientation/heading-magnetic-deg") + 0.50);
								if (tgtHdg==0) tgtHdg=360;
								me.hdg_setting.setValue(tgtHdg);
								me.lateral_mode.setValue(2);		# HDG HOLD
							}
						}
						# hold current vertical speed
						var vs = getprop("instrumentation/inst-vertical-speed-indicator/indicated-speed-fpm");
						vs = int(vs/100)*100;
						if (vs<-8000) vs = -8000;
						if (vs>6000) vs = 6000;
						me.vs_setting.setValue(vs);
						if(vs == 0)
						{
							me.target_alt.setValue(current_alt);
						}
						else
						{
							me.target_alt.setValue(me.alt_setting.getValue());
						}
						me.vertical_mode.setValue(2);		# V/S
						me.autothrottle_mode.setValue(5);	# A/T SPD
					}
				}
				else
				{
					if (btn==1)	#APP button
					{
						lgsmode = me.vertical_mode.getValue();
						if(lgsmode == 6)	# Already in G/S mode
						{
							me.vertical_mode.setValue(1);	# Keep current altitude
							me.gs_armed.setValue(0);		# Disarm
						}
						elsif(me.gs_armed.getValue())		# G/S armed but not captured yet
						{
							me.gs_armed.setValue(0);		# Disarm
						}
						else
						{
							me.gs_armed.setValue(1);		# G/S arm
						}
					}
					llocmode = me.lateral_mode.getValue();
					if(llocmode == 4)		# Alrady in LOC mode
					{
						# set target to current magnetic heading
						tgtHdg = int(getprop("orientation/heading-magnetic-deg") + 0.50);
						if (tgtHdg==0) tgtHdg=360;
						me.hdg_setting.setValue(tgtHdg);
						me.lateral_mode.setValue(2);		# Keep current headding
						me.loc_armed.setValue(0);			# Disarm
					}
					elsif(me.loc_armed.getValue())			# LOC armed but not captured yet
					{
						if(!me.gs_armed.getValue())			# G/S not armed
						{
							me.loc_armed.setValue(0);		# Disarm
						}
					}
					else
					{
						me.loc_armed.setValue(1);			# LOC arm
					}
				}
			}
		}
	},
###################
	setAP : func{
		var output=1-me.AP.getValue();
		var disabled = me.AP_disengaged.getValue();
		if((output==0)and(getprop("position/gear-agl-ft")<200))
		{
			disabled = 1;
			copilot("Captain, autopilot won't engage below 200ft.");
		}
		if((disabled)and(output==0)){output = 1;me.AP.setValue(0);}
		if (output==1)
		{
			var msg="";
			var msg2="";
			var msg3="";
			if (abs(getprop("controls/flight/rudder-trim"))>0.04)	msg  = "rudder";
			if (abs(getprop("controls/flight/elevator-trim"))>0.04) msg2 = "pitch";
			if (abs(getprop("controls/flight/aileron-trim"))>0.04)	msg3 = "aileron";
			if (msg ~ msg2 ~ msg3 != "")
			{
				if ((msg != "")and(msg2!=""))
					msg = msg ~ ", " ~ msg2;
				else
					msg = msg ~ msg2;
				if ((msg != "")and(msg3!=""))
					msg = msg ~ " and " ~ msg3;
				else
					msg = msg ~ msg3;
				copilot("Captain, autopilot disengaged. Careful, check " ~ msg ~ " trim!");
			}
		}
		else
			if(me.lateral_mode.getValue() != 3) me.input(0,1);
		setprop("autopilot/internal/target-pitch-deg",0);
		setprop("autopilot/internal/target-roll-deg",0);
		me.AP_passive.setValue(output);
	},
###################
	setbank : func{
		var banklimit=me.bank_switch.getValue();
		var lmt=25;
		if(banklimit>0){lmt=banklimit * 5};
		me.bank_max.setValue(lmt);
		lmt = -1 * lmt;
		me.bank_min.setValue(lmt);
	},
###################
	updateATMode : func()
	{
		var idx=me.autothrottle_mode.getValue();
		me.AP_speed_mode.setValue(me.spd_list[idx]);
	},
#################
	wpChanged : func{
		if (((getprop("/autopilot/route-manager/wp/id")=="")or
			(!getprop("/autopilot/route-manager/active")))and
			(me.lateral_mode.getValue() == 3)and
			me.AP.getValue())
		{
			# LNAV active, but route manager is disabled now => switch to HDG HOLD (current heading)
			me.input(0,2);
		}
	},
#################
	ap_update : func{
		current_alt = getprop("instrumentation/altimeter/indicated-altitude-ft");
		var VS =getprop("velocities/vertical-speed-fps");
		var TAS =getprop("velocities/uBody-fps");
		if(TAS < 10) TAS = 10;
		if(VS < -200) VS=-200;
		if (abs(VS/TAS)<=1)
		{
			var FPangle = math.asin(VS/TAS);
			FPangle *=90;
			setprop("autopilot/internal/fpa",FPangle);
		}
		var msg=" ";
		if(me.FD.getValue())
		{
			msg="FLT DIR";
		}
		if(me.AP.getValue())
		{
			msg="A/P";
			if(me.rollout_armed.getValue())
			{
				msg="LAND 3";
			}
		}
		me.AP_annun.setValue(msg);
		var tmp = abs(me.vs_setting.getValue());
		me.vs_display.setValue(tmp);
		tmp = abs(me.fpa_setting.getValue());
		me.fpa_display.setValue(tmp);
		msg="";
		var hdgoffset = me.hdg_setting.getValue()-getprop("orientation/heading-magnetic-deg");
		if(hdgoffset < -180) hdgoffset +=360;
		if(hdgoffset > 180) hdgoffset +=-360;
		setprop("autopilot/internal/fdm-heading-bug-error-deg",hdgoffset);

		if(me.step==0){ ### glideslope armed ?###
			msg="";
			if(me.gs_armed.getValue())
			{
				msg="G/S";
				var gsdefl = getprop("instrumentation/nav/gs-needle-deflection");
				var gsrange = getprop("instrumentation/nav/gs-in-range");
				if ((gsdefl< 0.5 and gsdefl>-0.5)and
					gsrange)
				{
					me.vertical_mode.setValue(6);
					me.gs_armed.setValue(0);
				}
			}
			elsif(me.flare_armed.getValue())
			{
				msg="FLARE";
			}
			elsif(me.vnav_armed.getValue())
			{
				msg = "VNAV";
			}
			me.AP_pitch_arm.setValue(msg);

		}elsif(me.step==1){ ### localizer armed ? ###
			msg="";
			if(me.loc_armed.getValue())
			{
				msg="LOC";
				if (getprop("instrumentation/nav/signal-quality-norm") > 0.9)
				{
					var hddefl = getprop("instrumentation/nav/heading-needle-deflection");
					var vtemp = 9.9;
					if(!getprop("instrumentation/nav/nav-loc"))
					{
						var vspeed = getprop("instrumentation/airspeed-indicator/indicated-speed-kt");
						var vcourse = getprop("instrumentation/nav/heading-deg");
						var vdistance = getprop("instrumentation/nav/nav-distance");
						vtemp = getprop("orientation/heading-deg");
						vcourse = abs(vcourse - vtemp);
						if (vcourse <= 90)
							vtemp = vcourse*vspeed*vdistance/(10*200*1852*15);
						if(vtemp > 9.9)
							vtemp = 9.9;
					}

					if(abs(hddefl) < vtemp)
					{
						me.lateral_mode.setValue(4);
						me.loc_armed.setValue(0);
					}
				}
			}
			elsif(me.lnav_armed.getValue())
			{
				if(getprop("position/gear-agl-ft") > 50)
				{
					msg = "";
					me.lnav_armed.setValue(0);		# Clear
					me.lateral_mode.setValue(3);	# LNAV
				}
				else
				{
					msg = "LNAV";
				}
			}
			elsif(me.rollout_armed.getValue())
			{
				msg = "ROLLOUT";
			}
			me.AP_roll_arm.setValue(msg);

		}elsif(me.step == 2){ ### check lateral modes  ###
			var idx = me.lateral_mode.getValue();
			if ((idx == 1) or (idx == 2))
			{
				if(getprop("position/gear-agl-ft") > 50)
				{
					# switch between HDG SEL to HDG HOLD
					if (abs(getprop("orientation/heading-magnetic-deg")-me.hdg_setting.getValue())<2)
						idx = 2; # HDG HOLD
					else
						idx = 1; # HDG SEL
				}
			}
			elsif(idx == 4)		# LOC
			{
				if((me.rollout_armed.getValue())
					and (getprop("position/gear-agl-ft") < 5))
				{
					me.rollout_armed.setValue(0);
					idx = 5;	# ROLLOUT
				}
			}
			elsif(idx == 5)									# ROLLOUT
			{
				if(getprop("velocities/groundspeed-kt") < 5)
				{
					me.AP.setValue(0);				# Autopilot off
					if(!me.FD.getValue())
					{
						idx = 0;	# NO MODE
					}
					else
					{
						idx = 1; 	# HDG SEL
					}
				}
			}
			me.lateral_mode.setValue(idx);
			me.AP_roll_mode.setValue(me.roll_list[idx]);
			me.AP_roll_engaged.setBoolValue(idx > 0);

		}elsif(me.step==3){ ### check vertical modes  ###
			if(getprop("instrumentation/airspeed-indicator/indicated-speed-kt") < 100)
			{
				setprop("autopilot/internal/airport-height", current_alt);
			}
			var idx=me.vertical_mode.getValue();
			var test_fpa=me.vs_fpa_selected.getValue();
			if(idx==2 and test_fpa)idx=9;
			if(idx==9 and !test_fpa)idx=2;
			if ((idx==8)or(idx==1)or(idx==2)or(idx==9))
			{
				offset = (abs(getprop("instrumentation/inst-vertical-speed-indicator/indicated-speed-fpm")) / 8);
				if(offset < 200)
				{
					offset = 200;
				}
				# flight level change mode
				if (abs(current_alt - me.alt_setting.getValue()) < offset)
				{
					# within MCP altitude: switch to ALT HOLD mode
					idx=1;
					if(me.autothrottle_mode.getValue() != 0)
					{
						me.autothrottle_mode.setValue(5);	# A/T SPD
					}
					me.vs_setting.setValue(0);
				}
				if((me.mach_setting.getValue() >= 0.840)
					and (me.ias_mach_selected.getValue() == 0)
					and (current_alt < me.target_alt.getValue()))
				{
					me.ias_mach_selected.setValue(1);
					me.mach_setting.setValue(0.840);
				}
				elsif((me.ias_setting.getValue() >= 310)
					and (me.ias_mach_selected.getValue() == 1)
					and (current_alt > me.target_alt.getValue()))
				{
					me.ias_mach_selected.setValue(0);
					me.ias_setting.setValue(310);
				}
			}
			elsif(idx == 3)		# VNAV PATH
			{
				if((me.mach_setting.getValue() > 0.841)
					and (me.ias_mach_selected.getValue() == 0))
				{
					me.ias_mach_selected.setValue(1);
					me.mach_setting.setValue(0.840);
				}
				elsif((me.ias_setting.getValue() > 321)
					and (me.ias_mach_selected.getValue() == 1))
				{
					me.ias_mach_selected.setValue(0);
					me.ias_setting.setValue(320);
				}
				elsif(me.ias_mach_selected.getValue() == 0)
				{
					if(current_alt < 10000)
					{
						me.ias_setting.setValue(250);
					}
					else
					{
						me.ias_setting.setValue(320);
					}
				}
			}
			elsif(idx == 4)		# VNAV SPD
			{
				if(getprop("/controls/flight/flaps") > 0.033)		# flaps 5
				{
					me.ias_setting.setValue(180);
				}
				elsif(getprop("/controls/flight/flaps") > 0)		# flaps 1
				{
					me.ias_setting.setValue(195);
				}
				elsif(current_alt < 2000)
				{
					me.ias_setting.setValue(210);
				}
				elsif(current_alt < 10000)
				{
					me.ias_setting.setValue(250);
				}
				else
				{
					if((me.mach_setting.getValue() >= 0.840)
						and (me.ias_mach_selected.getValue() == 0)
						and (current_alt < me.target_alt.getValue()))
					{
						me.ias_mach_selected.setValue(1);
						me.mach_setting.setValue(0.840);
					}
					elsif((me.ias_setting.getValue() >= 310)
						and (me.ias_mach_selected.getValue() == 1)
						and (current_alt > me.target_alt.getValue()))
					{
						me.ias_mach_selected.setValue(0);
						me.ias_setting.setValue(310);
					}
					elsif(me.ias_mach_selected.getValue() == 0)
					{
						if(current_alt < 10000)
						{
							me.ias_setting.setValue(250);
						}
						else
						{
							me.ias_setting.setValue(320);
						}
					}
				}
				me.alt_setting.setValue(getprop("autopilot/route-manager/cruise/altitude-ft"));
				me.target_alt.setValue(me.alt_setting.getValue());
				if (abs(current_alt
					- me.alt_setting.getValue()) < 200)
				{
					# within target altitude: switch to VANV PTH mode
					idx=3;
					if(me.autothrottle_mode.getValue() != 0)
					{
						me.autothrottle_mode.setValue(5);	# A/T SPD
					}
					me.vs_setting.setValue(0);
				}
			}
			elsif(idx == 6)
			{
				if((getprop("position/gear-agl-ft") < 50)
					and (me.flare_armed.getValue()))
				{
					me.flare_armed.setValue(0);
					idx = 7;
				}
				elsif(me.AP.getValue() and (getprop("position/gear-agl-ft") < 1500))
				{
					me.rollout_armed.setValue(1);		# ROLLOUT
					me.flare_armed.setValue(1);			# FLARE
					setprop("autopilot/settings/flare-speed-fps", 0);
				}
			}
			elsif(idx == 7)								# FLARE
			{
				if(me.autothrottle_mode.getValue())
				{
					if(getprop("position/gear-agl-ft") < 25)
					{
						me.autothrottle_mode.setValue(4);	# A/T IDLE
					}
				}
				if(getprop("velocities/groundspeed-kt") < 5)
				{
					if(!me.FD.getValue())
					{
						idx = 0;	# NO MODE
					}
					else
					{
						idx = 1; 	# ALT
					}
				}
			}
			if((current_alt
				- getprop("autopilot/internal/airport-height")) > 400) # Take off mode and above baro 400 ft
			{
				if(me.vnav_armed.getValue())
				{
					if(me.alt_setting.getValue() == int(current_alt))
					{
						idx = 3;		# VNAV PTH
					}
					else
					{
						idx = 4;		# VNAV SPD
					}
					me.vnav_armed.setValue(0);
				}
			}
			me.vertical_mode.setValue(idx);
			me.AP_pitch_mode.setValue(me.pitch_list[idx]);
			me.AP_pitch_engaged.setBoolValue(idx>0);

		}
		elsif(me.step == 4) 			### Auto Throttle mode control  ###
		{
			# Thrust reference rate calculation. This should be provided by FMC
			derate = getprop("consumables/fuel/total-fuel-lbs") + getprop("/sim/weight[0]/weight-lb") + getprop("/sim/weight[1]/weight-lb");
			derate = 0.3 - derate * 0.00000083;
			# IAS and MACH number update in back ground
			if(me.ias_mach_selected.getValue() == 1)
			{
				temp = int(getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));
				me.ias_setting.setValue(temp);
			}
			else
			{
				temp = (int(getprop("instrumentation/airspeed-indicator/indicated-mach") * 1000) / 1000);
				me.mach_setting.setValue(temp);
			}
			# Auto throttle arm switch is offed
			if((me.at1.getValue() == 0) or (me.at2.getValue() == 0))
			{
				me.autothrottle_mode.setValue(0);
			}
			# auto-throttle disengaged when reverser is enabled
			elsif (getprop("controls/engines/engine/reverser"))
			{
				me.autothrottle_mode.setValue(0);
			}
			elsif(me.autothrottle_mode.getValue() == 2)		# THR REF
			{
				if((getprop("instrumentation/airspeed-indicator/indicated-speed-kt") > 80)
					and ((current_alt - getprop("autopilot/internal/airport-height")) < 400))
				{
					me.autothrottle_mode.setValue(3);			# HOLD
				}
				elsif((me.vertical_mode.getValue() != 3)		# not VNAV PTH
					and (me.vertical_mode.getValue() != 5))		# not VNAV ALT
				{
					if((getprop("/controls/flight/flaps") == 0)		# FLAPs up
						and (me.vertical_mode.getValue() != 4))		# not VNAV SPD
					{
						me.autothrottle_mode.setValue(5);		# SPD
					}
					else
					{
						# Thurst limit varis on altitude
						if(current_alt < 35000)
						{
							thrust_lmt = derate / 35000 * abs(current_alt) + (0.95 - derate);
						}
						else
						{
							thrust_lmt = 0.96;
						}
						setprop("/controls/engines/engine[0]/throttle", thrust_lmt);
						setprop("/controls/engines/engine[1]/throttle", thrust_lmt);
					}
				}
			}
			elsif((me.autothrottle_mode.getValue() == 4)		# Auto throttle mode IDLE 
				and (me.vertical_mode.getValue() == 8)			# FLCH SPD mode
				and (getprop("engines/engine[0]/n1") < 30)		# #1Thrust is actual flight idle
				and (getprop("engines/engine[1]/n1") < 30))		# #2Thrust is actual flight idle
			{
				me.autothrottle_mode.setValue(3);				# HOLD
			}
			# Take off mode and above baro 400 ft
			elsif((current_alt - getprop("autopilot/internal/airport-height")) > 400)
			{
				if(me.autothrottle_mode.getValue() == 1)		# THR
				{
					if(current_alt < 35000)
					{
						thrust_lmt = derate / 35000 * abs(current_alt) + (0.95 - derate);
					}
					else
					{
						thrust_lmt = 0.96;
					}
					setprop("/controls/engines/engine[0]/throttle", thrust_lmt);
					setprop("/controls/engines/engine[1]/throttle", thrust_lmt);
				}
				elsif((me.vertical_mode.getValue() == 0)		# not set
					or ((me.autothrottle_mode.getValue() == 3)	# HOLD
					and (me.vertical_mode.getValue() != 8)))
				{
					if(getprop("/controls/flight/flaps") == 0)
					{
						me.autothrottle_mode.setValue(5);		# SPD
					}
					else
					{
						me.autothrottle_mode.setValue(2);		# THR REF
					}
				}
				elsif(me.vertical_mode.getValue() == 4)			# VNAV SPD
				{
					me.autothrottle_mode.setValue(2);			# THR REF
				}
				elsif(me.vertical_mode.getValue() == 3)			# VNAV PATH
				{
					me.autothrottle_mode.setValue(5);			# SPD
				}
			}
			elsif((getprop("position/gear-agl-ft") > 100)		# Approach mode and above 100 ft
					and (me.vertical_mode.getValue() == 6)) 
			{
				me.autothrottle_mode.setValue(5);				# SPD
			}
			idx = me.autothrottle_mode.getValue();
			me.AP_speed_mode.setValue(me.spd_list[idx]);
		}
		elsif(me.step==5)
		{
			if (getprop("/autopilot/route-manager/active")){
				max_wpt=getprop("/autopilot/route-manager/route/num");
				atm_wpt=getprop("/autopilot/route-manager/current-wp");
				wpt_distance = getprop("/autopilot/route-manager/wp/dist");
				if(wpt_distance == nil) wpt_distance = 36000;
				max_wpt-=1;
				if(wpt_distance < (5 * getprop("/instrumentation/airspeed-indicator/indicated-mach")))
 				{
 					if (getprop("/autopilot/route-manager/current-wp")<=max_wpt){
						atm_wpt+=1;
						props.globals.getNode("/autopilot/route-manager/current-wp").setValue(atm_wpt);
					}
				}
			}
		}elsif(me.step==6)
		{
			if(getprop("/controls/flight/flaps") == 0)
			{
				me.auto_popup.setValue(0);
			}
			ma_spd=getprop("/instrumentation/airspeed-indicator/indicated-mach");
			banklimit=getprop("/instrumentation/afds/inputs/bank-limit-switch");
			if(banklimit==0)
			{
				if(ma_spd > 0.85)
				{
					lim=5;
				}
				elsif(ma_spd > 0.6666)
				{
					lim=10;
				}
				elsif(ma_spd > 0.5)
				{
					lim=20;
				}
				elsif(ma_spd > 0.3333)
				{
					lim=30;
				}
				else
				{
					lim=35;
				}
				props.globals.getNode("/instrumentation/afds/settings/bank-max").setValue(lim);
				lim = -1 * lim;
				props.globals.getNode("/instrumentation/afds/settings/bank-min").setValue(lim);
			}
		}

		me.step+=1;
		if(me.step>6)me.step =0;
	},
};
#####################


var afds = AFDS.new();

setlistener("/sim/signals/fdm-initialized", func {
	settimer(update_afds,6);
	print("AFDS System ... check");
});

var update_afds = func {
	afds.ap_update();
	settimer(update_afds, 0);
}
