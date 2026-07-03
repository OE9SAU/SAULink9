# Rogerbeep.tcl für SimplexLogic
# by OE9SAU v1.0

namespace eval Logic {

    #
    # Eigenes Reflector-Call
    #
    variable local_call "OEXXXX-X"

    #
    # Talker Ende
    #
    proc talker_stop {tg callsign} {

        variable local_call

        #
        # Lokal
        #
        if {$callsign eq $local_call} {

            playTone 1000 300 50
            playSilence 80
            playTone 1209 300 50

            puts "=====>>>>> RGR Lokal <<<<<====="

        } else {

            #
            # Netzwerk
            #
            playTone 500 300 150

            puts "=====>>>>> RGR Netzwerk <<<<<====="
        }
    }
}