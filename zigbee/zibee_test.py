# Setup
# pip install paho-mqtt

import time
import paho.mqtt.client as mqtt

# Configuration
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
# Replace with your actual Zigbee2MQTT device friendly name
DEVICE_NAME = "my-zigbee-switch" 

TOPIC_SET = f"zigbee2mqtt/{DEVICE_NAME}/set"

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT broker successfully!")
    else:
        print(f"Failed to connect, return code {rc}")

client = mqtt.Client()
client.on_connect = on_connect

client.connect(MQTT_BROKER, MQTT_PORT, 60)
client.loop_start()

try:
    print("Turning switch ON...")
    client.publish(TOPIC_SET, '{"state": "ON"}')
    time.sleep(5)

    print("Turning switch OFF...")
    client.publish(TOPIC_SET, '{"state": "OFF"}')
    time.sleep(2)

finally:
    client.loop_stop()
    client.disconnect()
    print("Test finished.")