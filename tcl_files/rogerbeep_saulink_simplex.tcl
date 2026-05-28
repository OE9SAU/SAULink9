namespace eval Logic {

    variable local_rx 0

    #
    # Lokaler RX erkannt
    #
    proc squelch_open {rx_id is_open} {

        variable local_rx

        if {$is_open} {

            set local_rx 1

            # puts "LOCAL RX OPEN"
            #
            # Nach 2 Sekunden zurücksetzen
            #
            after 2000 {
                namespace eval Logic {
                    variable local_rx 0
                }
            }
        }
    }

    proc send_rgr_sound {} {

        variable local_rx

        #
        # Lokal
        #
        if {$local_rx} {

            playTone 1000 300 50
            playSilence 80
            playTone 1209 300 50
			puts "=====>>>>> RGR LOKAL <<<<<====="									  

        #
        # Netzwerk
        #
        } else {

            playTone 500 300 150
			puts "=====>>>>> RGR NETZWERK <<<<<====="
        }
    }
}