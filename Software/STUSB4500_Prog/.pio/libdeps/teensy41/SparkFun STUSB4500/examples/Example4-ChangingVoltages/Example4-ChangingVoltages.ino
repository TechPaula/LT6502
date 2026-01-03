/*
  Changing Output Voltage on the Fly
  By: Alex Wende
  SparkFun Electronics
  Date: February 16th, 2021
  License: This code is public domain but you buy me a beer if you use this and we meet someday (Beerware license).
  Feel like supporting our work? Buy a board from SparkFun!
  https://www.sparkfun.com/products/15801
  
  This example demonstrates how to change the STUSB4500 output voltage without cycling power or pressing the
  reset button for the STUSB4500. Note that the STUSB4500 is not a voltage regulator, the voltages the board is 
  capable of outputting are only those supported by the USB-C power adapter connected.
  
  Quick-start:
  - Use a SparkFun RedBoard Qwiic -or- attach the Qwiic Shield to your Arduino/Photon/ESP32 or other
  - Modify the voltages to match those supported by the power adapter (most common are 5,9,12,15,20V)
  - Upload the sketch
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
  
  /* Read the settings saved to the NVM map*/
  usb.read();

  /* Read the Power Data Objects (PDO) highest priority */
  Serial.print("PDO Number: ");
  Serial.println(usb.getPdoNumber());

  /* Read settings for PDO1 */
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

  /* Read settings for PDO2 */
  Serial.print("Voltage2 (V): ");
  Serial.println(usb.getVoltage(2));
  Serial.print("Current2 (A): ");
  Serial.println(usb.getCurrent(2));
  Serial.print("Lower Voltage Tolerance2 (%): ");
  Serial.println(usb.getLowerVoltageLimit(2));
  Serial.print("Upper Voltage Tolerance2 (%): ");
  Serial.println(usb.getUpperVoltageLimit(2));
  Serial.println();

  /* Read settings for PDO3 */
  Serial.print("Voltage3 (V): ");
  Serial.println(usb.getVoltage(3));
  Serial.print("Current3 (A): ");
  Serial.println(usb.getCurrent(3));
  Serial.print("Lower Voltage Tolerance3 (%): ");
  Serial.println(usb.getLowerVoltageLimit(3));
  Serial.print("Upper Voltage Tolerance3 (%): ");
  Serial.println(usb.getUpperVoltageLimit(3));
  Serial.println();

  /* Read the flex current value */
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
  /*
   * The output voltage shouldn't change yet. This is because
   * the soft reset function needs to called to take affect.
  */
  Serial.println("\nSet PDO3 to 9V (nothing should happen)");
  usb.setPdoNumber(3); //Make sure PDO3 is set to the highest priority for this example
  usb.setVoltage(3,9.0);
  delay(3000);

  // Now the voltage should change to 9V after calling the softReset function
  Serial.println("Performing a soft reset should now let the voltage change");
  usb.softReset();
  delay(3000);

  // Let's try changing to 12V now
  Serial.println("Setting PDO3 to 12V");
  usb.setVoltage(3,12.0);
  usb.softReset();
  delay(3000);

  /* 
   *  Instead of writing a voltage, you can also just change the PDO number,
   *  and then call softReset.
   *  
   *  USB PD must be able to support at least 5V. As a result, PDO1 is fixed
   *  at 5V and cannot be changed. Switching to PDO1 is a fast and easy way
   *  swap to 5V without having to set the voltage to 5V.
  */
  Serial.println("Switching to PDO1");
  usb.setPdoNumber(1);
  usb.softReset();
  delay(3000);
}
