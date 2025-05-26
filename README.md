# liveGnuplot
plotting slow daily data to gnuplot displays in real time. 

This code is a Perl wrapper around gnuplot, that displays multiple daily graphs of recent real-time data, updating continuously. The visualization makes it easy to compare, for instance, the last week's daily temperature curves. 

A tool to scrape parameter data from MQTT topics and store in compatible log files is included. 

    alias plotSolar='/home/bomr/Util/pl/plotSolar.pl --rec=8 --rep=1 --solarLogDir=/usr1/data --logBaseName=_d1MiniADS1115'
    alias plotTemp='cd ~/Downloads/Data && ~/Util/pl/plotTemp.pl --recent=8 --repeat=1'


The _**tasmota2MQTTscan.pl**_ tool heavily exploits the JSON::Path module to allow the user to concisely specify a path to a value that is stored in a JSON Object (I hope I've used that terminology correctly). It allows the user to specify a MQTT broker & topic, and to extract a scalar value from the JSON payload of the topic:

    bomr@orangepi3:~/Util/Projects/liveGnuplot$ ./tasmota2MQTTscan.pl --mqttBroker='192.168.1.100' -mqttOptions="-v" --mqttTopic='tele/tasmota_F74C1D/SENSOR' --mqttJPath="$..Temperature" --verbose=1 --logDirName=/home/bomr/data

This repository now contains code gragments that are working toward a generic MQTT scraper whihc will allow multiple MQTT brokers and/or MQTTTopics to be subscribed and logged to flat files (initially, compatible with gnuplot, for plotting). The main challenges in the code are parsing the JSON config file, establising MQTT subscriptions, and handling the data in callbacks from the MQTT CLient code (Net::MQTT:Simple). The latter is presetly the most challenging, requiring to get an Object instance callback subroutine to be used in the callback from Net::MQTT::Simple. 

