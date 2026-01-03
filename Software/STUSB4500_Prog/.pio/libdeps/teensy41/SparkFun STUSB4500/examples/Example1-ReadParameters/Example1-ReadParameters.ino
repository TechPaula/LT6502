/*
  Reading the Settings Saved to the STUSB4500 Power Delivery Board
  By: Alex Wende
  SparkFun Electronics
  Date: February 6th, 2020
  License: This code is public domain but you buy me a beer if you use this and we meet someday (Beerware license).
  Feel like supporting our work? Buy a board from SparkFun!
  https://www.sparkfun.com/products/15801
  
  This example demonstrates how to read all of the NVM settings saved to the STUSB4500
  
  Quick-start:
  - Use a SparkFun RedBoard Qwiic -or- attach the Qwiic Shield to your Arduino/Photon/ESP32 or other
  - Upload example sketch
  - Plug the Power Delivery Board onto the RedBoard/shield
  - Open the serial monitor and set the baud rate to 115200
  - The RedBoard will connect to the Power Delivery Board over I2C and print out all of the settings saved.
*/
// Include the SparkFun STUSB4500 library.
// Click here to get the library: http://librarymanager/All#SparkFun_STUSB4500

#include <Wire.h>
#include <SparkFun_STUSB4500.h>

STUSB4500 usb;

void setup() 
{
  Serial.begin(115200);  
  Wire.begin(); //Join I2C bus
  
  delay(500);
  
  /* The Power Delivery board uses the default settings with address 0x28 using Wire.
  
     Opionally, if the address jumpers are modified, or using a different I2C bus,
     these parameters can be changed here. E.g. usb.begin(0x29,Wire1)
  
     It will return true on success or false on failure to communicate. */
  if(!usb.begin())
  {
    Serial.println("Cannot connect to STUSB4500.");
    Serial.println("Is the board connected? Is the device ID correct?");
    while(1);
  }
  
  Serial.println("Connected to STUSB4500!");
  delay(100);

  /* Read the Power Data Objects (PDO) highest priority (1-3) */
  Serial.print("PDO Number: ");
  Serial.println(usb.getPdoNumber());

  /* Read settings for PDO1
     - Voltage fixed at 5V
     - Current value for PDO1 0-5A, if 0 used, FLEX_I value is used
     - Under Voltage Lock Out fixed at 3.3V (but will always return 0)
     - Over Voltage Lock Out 5-20%
  */
  Serial.println();
  Serial.print("Voltage1 (V): ");
  Serial.println(usb.getVoltage(1));
  Serial.print("Current1 (A): ");
  Serial.println(usb.getCurrent(1));
  Serial.print("Lower Voltage Tolerance1 (%): ");
  Serial.println(usb.getLowerVoltageLimit(1));
  Serial.print("Upper Voltage Tolerance1 (%): ");
  Serial.println(usb.getUpperVoltageLimit(1));
  Serial.println();

  /* Read settings for PDO2
    - Voltage 5-20V
    - Current value for PDO2 0-5A, if 0 used, FLEX_I value is used
    - Under Voltage Lock Out 5-20%
    - Over Voltage Lock Out 5-20%
  */
  Serial.print("Voltage2 (V): ");
  Serial.println(usb.getVoltage(2));
  Serial.print("Current2 (A): ");
  Serial.println(usb.getCurrent(2));
  Serial.print("Lower Voltage Tolerance2 (%): ");
  Serial.println(usb.getLowerVoltageLimit(2));
  Serial.print("Upper Voltage Tolerance2 (%): ");
  Serial.println(usb.getUpperVoltageLimit(2));
  Serial.println();

  /* Read settings for PDO3
     - Voltage 5-20V
     - Current value for PDO3 0-5A, if 0 used, FLEX_I value is used
     - Under Voltage Lock Out 5-20%
     - Over Voltage Lock Out 5-20%
  */
  Serial.print("Voltage3 (V): ");
  Serial.println(usb.getVoltage(3));
  Serial.print("Current3 (A): ");
  Serial.println(usb.getCurrent(3));
  Serial.print("Lower Voltage Tolerance3 (%): ");
  Serial.println(usb.getLowerVoltageLimit(3));
  Serial.print("Upper Voltage Tolerance3 (%): ");
  Serial.println(usb.getUpperVoltageLimit(3));
  Serial.println();

  /* Read the flex current value (FLEX_I) */
  Serial.print("Flex Current: ");
  Serial.println(usb.getFlexCurrent());

  /* Read the External Power capable bit */
  Serial.print("External Power: ");
  Serial.println(usb.getExternalPower());

  /* Read the USB Communication capable bit */
  Serial.print("USB Communication Capable: ");
  Serial.println(usb.getUsbCommCapable());

  /* Read the POWER_OK pins configuration */
  Serial.print("Configuration OK GPIO: ");
  Serial.println(usb.getConfigOkGpio());

  /* Read the GPIO pin configuration */
  Serial.print("GPIO Control: ");
  Serial.println(usb.getGpioCtrl());

  /* Read the bit that enables VBUS_EN_SNK pin only when power is greater than 5V */
  Serial.print("Enable Power Only Above 5V: ");
  Serial.println(usb.getPowerAbove5vOnly());
  
  /* Read bit that controls if the Source or Sink device's 
     operating current is used in the RDO message */
  Serial.print("Request Source Current: ");
  Serial.println(usb.getReqSrcCurrent());
}

void loop()
{
}
