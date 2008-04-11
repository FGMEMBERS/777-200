# 777-200 systems
#Syd Adams
#
var SndOut = props.globals.getNode("/sim/sound/Ovolume",1);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10).stop();
var fuel_density =0;

#EFIS specific class 
# ie: var efis = EFIS.new("instrumentation/EFIS");
var EFIS = {
    new : func(prop1){
        m = { parents : [EFIS]};
        m.radio_list=["instrumentation/comm/frequencies","instrumentation/comm[1]/frequencies","instrumentation/nav/frequencies","instrumentation/nav[1]/frequencies"];
        m.efis = props.globals.getNode(prop1,1);
        m.kpa_mode = m.efis.getNode("kpa-mode",1);
        m.kpa_mode.setBoolValue(0);
        m.kpa_output = m.efis.getNode("inhg-kpa",1);
        m.kpa_output.setDoubleValue(0);
        m.temp = m.efis.getNode("fixed-temp",1);
        m.temp.setDoubleValue(0);
        m.alt_meters = m.efis.getNode("alt-meters",1);
        m.alt_meters.setBoolValue(0);
        m.radio = m.efis.getNode("radio-mode",1);
        m.radio.setIntValue(0);
        m.radio_selected = m.efis.getNode("radio-selected",1);
        m.radio_selected.setDoubleValue(getprop("instrumentation/comm/frequencies/selected-mhz"));
        m.radio_standby = m.efis.getNode("radio-standby",1);
        m.radio_standby.setDoubleValue(getprop("instrumentation/comm/frequencies/standby-mhz"));
    return m;
    },
#### convert inhg to kpa ####
    calc_kpa : func{
        var kp = getprop("instrumentation/altimeter/setting-inhg");
        if(me.kpa_mode.getBoolValue()){
            kp= kp * 33.8637526;
            }else{
                kp = kp * 100;
            }
        me.kpa_output.setValue(kp);
        },
#### update temperature display ####
    update_temp : func{
        var tmp = getprop("/environment/temperature-degc");
        if(tmp < 0.00){
            tmp = -1 * tmp;
        }
        me.temp.setValue(tmp);
    },
#### swap radio freq ####
    swap_freq : func(){
        var tmpsel = me.radio_selected.getValue();
        var tmpstb = me.radio_standby.getValue();
        me.radio_selected.setValue(tmpstb);
        me.radio_standby.setValue(tmpsel);
        me.update_frequencies();
    },
#### copy efis freq to radios ####
    update_frequencies : func(){
        var fq = me.radio.getValue();
        setprop(me.radio_list[fq]~"/selected-mhz",me.radio_selected.getValue());
        setprop(me.radio_list[fq]~"/standby-mhz",me.radio_standby.getValue());
    },
#### modify efis radio standby freq ####
    set_freq : func(fdr){
        var rd = me.radio.getValue();
        var frq =me.radio_standby.getValue();
        var frq_step =0;
        if(rd >=2){
            if(fdr ==1)frq_step = 0.05;
            if(fdr ==-1)frq_step = -0.05;
            if(fdr ==10)frq_step = 1.0;
            if(fdr ==-10)frq_step = -1.0;
            frq += frq_step;
            if(frq > 118.000)frq -= 10.000;
            if(frq<108.000) frq += 10.000;
        }else{
            if(fdr ==1)frq_step = 0.025;
            if(fdr ==-1)frq_step = -0.025;
            if(fdr ==10)frq_step = 1.0;
            if(fdr ==-10)frq_step = -1.0;
            frq += frq_step;
            if(frq > 136.000)frq -= 18.000;
            if(frq<118.000) frq += 18.000;
        }
        me.radio_standby.setValue(frq);
        me.update_frequencies();
    },

    set_radio_mode : func(rm){
        me.radio.setIntValue(rm);
        me.radio_selected.setDoubleValue(getprop(me.radio_list[rm]~"/selected-mhz"));
        me.radio_standby.setDoubleValue(getprop(me.radio_list[rm]~"/standby-mhz"));
    },

set_radar_range : func(rtmp){
    var rng =getprop("instrumentation/radar/range");
    if(rtmp ==1){
        rng =rng * 2;
        if(rng > 640) rng = 640;
    }elsif(rtmp =-1){
        rng =rng / 2;
        if(rng < 10) rng = 10;
    }
    setprop("instrumentation/radar/range",rng);
    setprop("instrumentation/radar/reference-range-nm",rng);
}

};

#Engine control class 
# ie: var Eng = Engine.new(engine number);
var Engine = {
    new : func(eng_num){
        m = { parents : [Engine]};
        m.fdensity = getprop("consumables/fuel/tank/density-ppg");
        if(m.fdensity ==nil)m.fdensity=6.72;
        m.eng = props.globals.getNode("engines/engine["~eng_num~"]",1);
        m.running = m.eng.getNode("running",1);
        m.running.setBoolValue(0);
        m.n1 = m.eng.getNode("n1",1);
        m.n2 = m.eng.getNode("n2",1);
        m.rpm = m.eng.getNode("rpm",1);
        m.rpm.setDoubleValue(0);
        m.throttle_lever = props.globals.getNode("controls/engines/engine["~eng_num~"]/throttle-lever",1);
        m.throttle_lever.setDoubleValue(0);
        m.throttle = props.globals.getNode("controls/engines/engine["~eng_num~"]/throttle",1);
        m.throttle.setDoubleValue(0);
        m.cutoff = props.globals.getNode("controls/engines/engine["~eng_num~"]/cutoff",1);
        m.cutoff.setBoolValue(1);
        m.fuel_out = props.globals.getNode("engines/engine["~eng_num~"]/out-of-fuel",1);
        m.fuel_out.setBoolValue(0);
        m.starter = props.globals.getNode("controls/engines/engine["~eng_num~"]/starter",1);
        m.fuel_pph=m.eng.getNode("fuel-flow_pph",1);
        m.fuel_pph.setDoubleValue(0);
        m.fuel_gph=m.eng.getNode("fuel-flow-gph",1);
        m.hpump=props.globals.getNode("systems/hydraulics/pump-psi["~eng_num~"]",1);
        m.hpump.setDoubleValue(0);
    return m;
    },
#### update ####
    update : func{
        if(me.fuel_out.getBoolValue())me.cutoff.setBoolValue(1);
        if(!me.cutoff.getBoolValue()){
        me.rpm.setValue(me.n1.getValue());
        me.throttle_lever.setValue(me.throttle.getValue());
        }else{
            me.throttle_lever.setValue(0);
            if(me.starter.getBoolValue()){
                me.spool_up();
            }else{
                var tmprpm = me.rpm.getValue();
                if(tmprpm > 0.0){
                    tmprpm -= getprop("sim/time/delta-realtime-sec") * 2;
                    me.rpm.setValue(tmprpm);
                }
            }
        }
    me.fuel_pph.setValue(me.fuel_gph.getValue()*me.fdensity);
    var hpsi =me.rpm.getValue();
    if(hpsi>60)hpsi = 60;
    me.hpump.setValue(hpsi);
    },

    spool_up : func{
        if(!me.cutoff.getBoolValue()){
        return;
        }else{
            var tmprpm = me.rpm.getValue();
            tmprpm += getprop("sim/time/delta-realtime-sec") * 5;
            me.rpm.setValue(tmprpm);
            if(tmprpm >= me.n1.getValue())me.cutoff.setBoolValue(0);
        }
    },

};


var Efis = EFIS.new("instrumentation/efis");
var LHeng=Engine.new(0);
var RHeng=Engine.new(1);

#############################

setlistener("/sim/signals/fdm-initialized", func {
    SndOut.setDoubleValue(0.15);
    setprop("/instrumentation/clock/flight-meter-hour",0);
    settimer(update_systems,2);
});

setlistener("/sim/signals/reinit", func {
    SndOut.setDoubleValue(0.15);
    setprop("/instrumentation/clock/flight-meter-hour",0);
    Shutdown();
});

setlistener("/sim/current-view/name", func(vw){
    var ViewName= vw.getValue();
    if(ViewName =="Pilot View" or ViewName =="CoPilot View"){
    SndOut.setDoubleValue(0.15);
    }else{
    SndOut.setDoubleValue(1.0);
    }
},1,0);

setlistener("/sim/model/start-idling", func(idle){
    var run= idle.getBoolValue();
    if(run){
    Startup();
    }else{
    Shutdown();
    }
},0,0);

var Startup = func{
setprop("controls/electric/engine[0]/generator",1);
setprop("controls/electric/engine[1]/generator",1);
setprop("controls/electric/engine[0]/bus-tie",1);
setprop("controls/electric/engine[1]/bus-tie",1);
setprop("controls/electric/APU-generator",1);
setprop("controls/electric/avionics-switch",1);
setprop("controls/electric/battery-switch",1);
setprop("controls/electric/inverter-switch",1);
setprop("controls/lighting/instrument-lights",1);
setprop("controls/lighting/nav-lights",1);
setprop("controls/lighting/beacon",1);
setprop("controls/lighting/strobe",1);
setprop("controls/lighting/wing-lights",1);
setprop("controls/lighting/taxi-lights",1);
setprop("controls/lighting/logo-lights",1);
setprop("controls/lighting/cabin-lights",1);
setprop("controls/lighting/landing-lights",1);
setprop("controls/engines/engine[0]/cutoff",0);
setprop("controls/engines/engine[1]/cutoff",0);
setprop("controls/fuel/tank/boost-pump",1);
setprop("controls/fuel/tank/boost-pump[1]",1);
setprop("controls/fuel/tank[1]/boost-pump",1);
setprop("controls/fuel/tank[1]/boost-pump[1]",1);
setprop("controls/fuel/tank[2]/boost-pump",1);
setprop("controls/fuel/tank[2]/boost-pump[1]",1);
}

var Shutdown = func{
setprop("controls/electric/engine[0]/generator",0);
setprop("controls/electric/engine[1]/generator",0);
setprop("controls/electric/engine[0]/bus-tie",0);
setprop("controls/electric/engine[1]/bus-tie",0);
setprop("controls/electric/APU-generator",0);
setprop("controls/electric/avionics-switch",0);
setprop("controls/electric/battery-switch",0);
setprop("controls/electric/inverter-switch",0);
setprop("controls/lighting/instrument-lights",0);
setprop("controls/lighting/nav-lights",0);
setprop("controls/lighting/beacon",0);
setprop("controls/lighting/strobe",0);
setprop("controls/lighting/wing-lights",0);
setprop("controls/lighting/taxi-lights",0);
setprop("controls/lighting/logo-lights",0);
setprop("controls/lighting/cabin-lights",0);
setprop("controls/lighting/landing-lights",0);
setprop("controls/engines/engine[0]/cutoff",1);
setprop("controls/engines/engine[1]/cutoff",1);
setprop("controls/fuel/tank/boost-pump",0);
setprop("controls/fuel/tank/boost-pump[1]",0);
setprop("controls/fuel/tank[1]/boost-pump",0);
setprop("controls/fuel/tank[1]/boost-pump[1]",0);
setprop("controls/fuel/tank[2]/boost-pump",0);
setprop("controls/fuel/tank[2]/boost-pump[1]",0);
}

var fuel_pump = func(){
    var tank=arg[0];
    var pump=arg[1];
    var pump2= 1- pump;
    var tnk = getprop("controls/fuel/tank["~tank~"]/boost-pump["~pump~"]");
    tnk=1-tnk;
    setprop("controls/fuel/tank["~tank~"]/boost-pump["~pump~"]",tnk);
    var tnk2 = getprop("controls/fuel/tank["~tank~"]/boost-pump["~pump2~"]");
    var ttl = tnk * tnk2;
    setprop("consumables/fuel/tank["~tank~"]/selected",ttl);
    }

var update_systems = func {
    Efis.calc_kpa();
    Efis.update_temp();
#    if(LHeng.starter.getValue()==1)LHeng.spool_up();
    LHeng.update();
#    if(RHeng.starter.getValue()==1)RHeng.spool_up();
    RHeng.update();
    settimer(update_systems,0);
}
