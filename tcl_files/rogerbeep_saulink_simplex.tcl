namespace eval Logic {

    variable is_network 0

    proc squelch_open {rx_id is_open} {

        variable is_network

        #
        # Lokale HF beendet
        #
        if {!$is_open} {

            set is_network 0
        }
    }

    proc send_rgr_sound {} {

        variable is_network

        if {$is_network} {

            puts "=====>>>>> RGR Netzwerk <<<<<====="

            playTone 500 300 150

        } else {

            puts "=====>>>>> RGR Lokal <<<<<====="

            playTone 1000 300 50
            playSilence 80
            playTone 1209 300 50
        }
    }
}