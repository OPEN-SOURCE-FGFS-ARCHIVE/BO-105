#
# Engine Control Panel Switches:
# by litzi
#

# called from ec145-ecp.xml
 
var engswitch = {
    pos: [0,0],
    
    init: func {
                me.get(0);
                me.get(1);
                },
                
    vent: func(eng) {
        curr = me.get(eng);
        if (curr == 0 ) {
             # ventilate engine for 20 sec
             engines.engine[eng].starterN.setValue(1);
             setprop("/controls/switches/ecp/vent["~eng~"]",1);
             settimer(func { engines.engine[eng].starterN.setValue(0); 
                             setprop("/controls/switches/ecp/vent["~eng~"]",0);} , 20); 
             
        }   
      
      },
    up: func(eng) {
        #left mouse button press
        curr = me.get(eng);
        
        if (curr == 0 or curr == 2) {
            var delay=0.1;
            if (curr==0 and engines.engine[!eng].starterN.getValue()) delay=11;
            me.set(eng, 1.0);
            
            if (curr==0) {
                # startup sequence
                settimer(func {
                  engines.engine[eng].reset();
                  engines.engine[eng].ignitionN.setValue(1);
                  engines.engine[eng].starterN.setValue(1);
                  engines.engine[eng].powerN.setValue(0.13);
                  settimer(func {
                    # finished startup
                    engines.engine[eng].starterN.setValue(0);
                    engines.engine[eng].ignitionN.setValue(0);
                    
                    if (bk117.engines.engine[eng].powerN.getValue() <= engines.engine[eng].pos.idle and me.get(eng) == 1) 
                                bk117.engines.engine[eng].powerN.setValue(engines.engine[eng].pos.idle);
                  }, 10);
                } , delay);
              } else {
                  engines.engine[eng].powerN.setValue(engines.engine[eng].pos.idle);
              }      
        } else {
            me.set(eng,2.0);
            engines.engine[eng].powerN.setValue(engines.engine[eng].pos.flight);
        }
    
        },
        
    down: func(eng) {
        #mid mouse button press
        curr = me.get(eng);
        
        if (curr == 1) {
            me.set(eng,0.0);
            bk117.engines.engine[eng].powerN.setValue(engines.engine[eng].pos.cutoff);
        }

        },

    train: func () {
      pos = getprop("/controls/switches/ecp/trainswitch") or 0;
      if (pos == 0) {
        if (me.pos[0]==2 and me.pos[1]==2) {
              engines.engine[0].powerN.setValue(0.22);            
              setprop("/controls/switches/ecp/trainswitch",1);
              }
      } else {
              engines.engine[0].powerN.setValue(engines.engine[0].pos.flight);
              setprop("/controls/switches/ecp/trainswitch",0);
      }  
    },
        
    get: func(eng) {
        me.pos[eng]=getprop("controls/switches/ecp/pos["~eng~"]") or 0;
        return me.pos[eng]; 
    },
    
    set: func(eng, p) {
        interpolate("controls/switches/ecp/pos["~eng~"]", p, 0.2);
        me.pos[eng] = p;
    }
};  
engswitch.init();












#
# Experimental code for
# syncronisation of engine n2 with rotor speed:
# by litzi
#

syncf = [aircraft.lowpass.new(3), aircraft.lowpass.new(3)];
syncf[0].set(0);
syncf[1].set(0);

var enginesyncfactor = func (eng) {
   
      # if no power just sync with n1, n2 will be free-wheeling
      if (engines.engine[eng].power == 0) syncf[eng].filter(0);    
      # if other engine off, sync this eng. with rotor
      elsif (engines.engine[!eng].power == 0) syncf[eng].filter(1);          
      # in all other cases weight by n1 relation with other engine   
      elsif (engines.engine[!eng].n1 > 0) syncf[eng].filter( engines.engine[eng].n1/engines.engine[!eng].n1 );
      
      return clamp(syncf[eng].get()); 
};

#
# Target for rotor speed (NR) datum:
# by litzi
#
nr_target = func () {
  if (engines.engine[0].power == engines.engine[0].pos.flight or
        engines.engine[1].power == engines.engine[1].pos.flight) {
        
      var ias = getprop("velocities/airspeed-kt") or 0;
      # NR law with air speed 98..101%
      return 1.01 - ias/4000;
        
  } else {
  
      # keep rotor in idle speed
      return 0.78;
  }
};

# FLIGHT MANUAL BK117 D-2, Section 7.9.2.4  
# In IDLE mode, the engine is basically controlled to a fix N2 value (N2_datum) of 78%. In
# some circumstances the N2 IDLE speed can be set to 85% to repect the required N1
# minumum fuel flow stop of 62%.  
