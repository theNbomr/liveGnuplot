# liveGnuplot
plotting slow daily data to gnuplot displays in real time. 

This code is a Perl wrapper around gnuplot, that displays multiple daily graphs of recent real-time data, updating continuously. The visualization makes it easy to compare, for instance, the last week's daily temperature curves. 

A tool to scrape parameter data from MQTT topics and store in compatible log files is included. 

    alias plotSolar='/home/bomr/Util/pl/plotSolar.pl --rec=8 --rep=1 --solarLogDir=/usr1/data --logBaseName=_d1MiniADS1115'
    alias plotTemp='cd ~/Downloads/Data && ~/Util/pl/plotTemp.pl --recent=8 --repeat=1'

The tasmota2MQTTscan.pl tool heavily expoilts the JSON::Path module to allow the user to concisely specify a path to a value that is stored in a JSON Ojject (I hope I've used that terminology correctly). It allows the user to specify a MQTT broker & topic, and to extract a scalar value from the JSON payload of the topic. 
    bomr@orangepi3:~/Util/Projects/liveGnuplot$ ./tasmota2MQTTscan.pl --mqttBroker='192.168.1.100' -mqttOptions="-v" --mqttTopic='tele/tasmota_F74C1D/SENSOR' --mqttJPath="$..Temperature" --verbose=1 --logDirName=/home/bomr/data

