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
        m.ias_mach_selected = m.AFDS_inputs.initNode("ias-mach-selected",0,"BOOL");
        m.hdg_trk_selected = m.AFDS_inputs.initNode("hdg-trk-selected",0,"BOOL");
        m.vs_fpa_selected = m.AFDS_inputs.initNode("vs-fpa-selected",0,"BOOL");
        m.bank_switch = m.AFDS_inputs.initNode("bank-limit-switch",0,"INT");

        m.ias_setting = m.AP_settings.initNode("target-speed-kt",200);# 100 - 399 #
        m.mach_setting = m.AP_settings.initNode("target-speed-mach",0.40);# 0.40 - 0.95 #
        m.vs_setting = m.AP_settings.initNode("vertical-speed-fpm",0); # -8000 to +6000 #
        m.hdg_setting = m.AP_settings.initNode("heading-bug-deg",360,"INT"); # 1 to 360
        m.fpa_setting = m.AP_settings.initNode("flight-path-angle",0); # -9.9 to 9.9 #
        m.alt_setting = m.AP_settings.initNode("target-altitude-ft",10000,"DOUBLE");
        m.auto_brake_setting = m.AP_settings.initNode("autobrake",0.000,"DOUBLE");

        m.trk_setting = m.AFDS_settings.initNode("trk",0,"INT");
        m.vs_display = m.AFDS_settings.initNode("vs-display",0);
        m.fpa_display = m.AFDS_settings.initNode("fpa-display",0);
        m.bank_min = m.AFDS_settings.initNode("bank-min",-25);
        m.bank_max = m.AFDS_settings.initNode("bank-max",25);
        m.pitch_min = m.AFDS_settings.initNode("pitch-min",-10);
        m.pitch_max = m.AFDS_settings.initNode("pitch-max",15);
        m.vnav_alt = m.AFDS_settings.initNode("vnav-alt",35000);

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

####    Inputs    ####
###################
    input : func(mode,btn){
        var fms = 0;
        if(mode==0){
            # horizontal AP controls
            if(me.lateral_mode.getValue() ==btn) btn=0;
            if (btn==2)
            {
                if (me.AP.getValue() and (me.lateral_mode.getValue()!=1))
                {
                    # set target to current magnetic heading
                    var tgtHdg = int(getprop("orientation/heading-magnetic-deg") + 0.50);
                    if (tgtHdg==0) tgtHdg=360;
                    me.hdg_setting.setValue(tgtHdg);
                    btn = 1;
                } else
                    btn = 0;
            }
            if(btn==3)
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
                    fms=1;
            }
            me.lateral_mode.setValue(btn);
        }elsif(mode==1){
            # vertical AP controls
            if(me.vertical_mode.getValue() ==btn) btn=0;
            if (btn==1){
                # hold current altitude
                if (me.AP.getValue())
                {
                    var alt = int((getprop("instrumentation/altimeter/indicated-altitude-ft")+50)/100)*100;
                    me.alt_setting.setValue(alt);
                } else
                    btn = 0;
            }
            if (btn==2){
                # hold current vertical speed
                if (me.AP.getValue())
                {
                    var vs = getprop("instrumentation/inst-vertical-speed-indicator/indicated-speed-fpm");
                    if (vs<0) vs -= 50;else vs+=50;
                    vs = int(vs/100)*100;
                    if (vs<-8000) vs = -8000;
                    if (vs>6000) vs = 6000;
                    me.vs_setting.setValue(vs);
                } else
                    btn = 0;
            }
            if (btn==8)
            {
                # change flight level
            }
            me.vertical_mode.setValue(btn);
        }elsif(mode==2){
            # throttle AP controls
            if(me.autothrottle_mode.getValue() ==btn) btn=0;
            if(btn and (getprop("position/altitude-agl-ft")<200))
            {
                btn=0;
                copilot("Captain, auto-throttle won't engage below 200ft.");
            } 
            me.autothrottle_mode.setValue(btn);
        }elsif(mode==3){
            var arm = 1-((me.loc_armed.getValue() or (4==me.lateral_mode.getValue())));
            if (btn==1){
                # toggle G/S and LOC arm
                var arm = arm or (1-(me.gs_armed.getValue() or (6==me.vertical_mode.getValue())));
                me.gs_armed.setValue(arm);
                if ((arm==0)and(6==me.vertical_mode.getValue())) me.vertical_mode.setValue(0);
            }
            me.loc_armed.setValue(arm);
            if((arm==0)and(4==me.lateral_mode.getValue())) me.lateral_mode.setValue(0);
        }
    },
###################
    setAP : func{
        var output=1-me.AP.getValue();
        var disabled = me.AP_disengaged.getValue();
        if((output==0)and(getprop("position/altitude-agl-ft")<200))
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
            if (abs(getprop("controls/flight/rudder-trim"))>0.04)   msg  = "rudder";
            if (abs(getprop("controls/flight/elevator-trim"))>0.04) msg2 = "pitch";
            if (abs(getprop("controls/flight/aileron-trim"))>0.04)  msg3 = "aileron";
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
        if(me.FD.getValue())msg="FLT DIR";
        if(me.AP.getValue())msg="A/P";
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
        if(getprop("position/altitude-agl-ft")<200){
            me.AP.setValue(0);
            me.autothrottle_mode.setValue(0);
        }

        if(me.step==0){ ### glideslope armed ?###
            msg="";
            if(me.gs_armed.getValue()){
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
            me.AP_roll_arm.setValue(msg);

        }elsif(me.step==2){ ### check lateral modes  ###
            var idx=me.lateral_mode.getValue();
            if ((idx == 1)or(idx == 2))
            {
                # switch between HDG SEL to HDG HOLD
                if (abs(getprop("orientation/heading-magnetic-deg")-me.hdg_setting.getValue())<2)
                    idx = 2; # HDG HOLD
                else
                    idx = 1; # HDG SEL
                me.lateral_mode.setValue(idx);
            }
            me.AP_roll_mode.setValue(me.roll_list[idx]);
            me.AP_roll_engaged.setBoolValue(idx>0);

        }elsif(me.step==3){ ### check vertical modes  ###
            var idx=me.vertical_mode.getValue();
            var test_fpa=me.vs_fpa_selected.getValue();
            if(idx==2 and test_fpa)idx=9;
            if(idx==9 and !test_fpa)idx=2;
            if ((idx==8)or(idx==1))
            {
                # flight level change mode
                if (abs(getprop("instrumentation/altimeter/indicated-altitude-ft")-me.alt_setting.getValue())<50)
                    # within target altitude: switch to ALT HOLD mode
                    idx=1;
                else
                    # outside target altitude: change flight level
                    idx=8;
                me.vertical_mode.setValue(idx);
            }
            me.AP_pitch_mode.setValue(me.pitch_list[idx]);
            me.AP_pitch_engaged.setBoolValue(idx>0);

        }elsif(me.step==4){             ### check speed modes  ###
            if (getprop("controls/engines/engine/reverser")) {
                # auto-throttle disables when reverser is enabled
                me.autothrottle_mode.setValue(0);
            }
        }

        me.step+=1;
        if(me.step>4)me.step =0;
    },
};
#####################


var afds = AFDS.new();

setlistener("/sim/signals/fdm-initialized", func {
    settimer(update_afds,5);
    print("AFDS System ... check");
});

var update_afds = func {
    afds.ap_update();

settimer(update_afds, 0);
}
