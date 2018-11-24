#### 433 Mhz vehicle unlocking with Arduino Duo

Having only one key fob for the van is anxiety-inducing in case it fails, so I decided to build a replacement with an Arduino/ATMega and a 433Mhz transceiver module.

Resources:

- [433Utils library by ninjablocks](https://github.com/ninjablocks/433Utils)
- [Alternative rc-switch library](https://github.com/sui77/rc-switch)

This was originally for a YouTube video which you can watch at [https://www.youtube.com/watch?v=ANQsj8KCzRc](https://www.youtube.com/watch?v=ANQsj8KCzRc).

[![Youtube Video](https://img.youtube.com/vi/ANQsj8KCzRc/0.jpg)](https://www.youtube.com/watch?v=ANQsj8KCzRc)


Code:

**sniffer.c**

    #include
    
    RCSwitch mySwitch = RCSwitch();
 
    void setup() {
    	Serial.begin(9600);
    	mySwitch.enableReceive(0); // Receiver on inerrupt 0 => that is pin #2
    }
 
    void loop() {
 
    	if (mySwitch.available()) {
    		int value = mySwitch.getReceivedValue();
    			if (value == 0) {
    				Serial.print("Unknown encoding");
    			} else {
    				Serial.print("Received ");
    				Serial.print( mySwitch.getReceivedValue() );
    				Serial.print(" / ");
    				Serial.print( mySwitch.getReceivedBitlength() );
    				Serial.print("bit ");
    				Serial.print("Protocol: ");
    				Serial.println( mySwitch.getReceivedProtocol() );
    			}
    		mySwitch.resetAvailable();
     
    	}
    }

**transmitter.c**

    #include <RCSwitch.h>
 
    #define CODE_one 10692289
    #define CODE_two 10692290
    #define CODE_three 10692296
     
    const int buttonPin = 4;
    const int ledPin =  13;
    int buttonPushCounter = 0;
    int buttonState = 0;
    int lastButtonState = 0;

    RCSwitch mySwitch = RCSwitch();
     
    void setup() {
    	pinMode(ledPin, OUTPUT);
    	pinMode(buttonPin, INPUT);
    	pinMode(7, OUTPUT);
    	Serial.begin(9600);
    	mySwitch.enableTransmit(7);
    }
    
    void loop() {
            buttonState = digitalRead(buttonPin);  
            if (buttonState != lastButtonState) {
              if (buttonState == HIGH) {
                buttonPushCounter++;
              }
              lastButtonState = buttonState;
               if (buttonPushCounter % 2 == 0) {
                digitalWrite(ledPin, LOW);
                mySwitch.send(CODE_one, 24);
                buttonPushCounter = 0;
              } else {
                digitalWrite(ledPin, HIGH);
                mySwitch.send(CODE_two, 24);
              }  
            }
         }
