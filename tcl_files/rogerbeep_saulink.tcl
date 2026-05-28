namespace eval Logic {

    variable is_rf 0

    proc squelch_open {rx_id is_open} {

        variable sql_rx_id
        variable is_rf

        set sql_rx_id $rx_id

        #
        # Lokaler RX beendet
        #
        if {!$is_open} {
            set is_rf 1
        }
    }

    proc send_rgr_sound {} {

        variable is_rf

        #
        # Netzwerk
        #
        if {!$is_rf} {

            # Signal wurde vom Netzwerk empfangen
            playTone 500 300 150
            puts "=====>>>>> RGR Netzwerk <<<<<====="
        #
        # Lokal
        #
        } else {

            # Signal wurde lokal empfangen
            playTone 1000 300 50
            playSilence 80
            playTone 1209 300 50
            puts "=====>>>>> RGR Lokal <<<<<====="
        }

        # Reset
        set is_rf 0
    }
}

# end of namespace
