# liveGnuplot
plotting slow daily data to gnuplot displays in real time. 

This code is a Perl wrapper around gnuplot, that displays multiple daily graphs of recent real-time data, updating continuously. The visualization makes it easy to compare, for instance, the last week's daily temperature curves. 

A tool to scrape parameter data from MQTT topics and store in compatible log files is included. 

    alias plotSolar='/home/bomr/Util/pl/plotSolar.pl --rec=8 --rep=1 --solarLogDir=/usr1/data --logBaseName=_d1MiniADS1115'
    alias plotTemp='cd ~/Downloads/Data && ~/Util/pl/plotTemp.pl --recent=8 --repeat=1'

