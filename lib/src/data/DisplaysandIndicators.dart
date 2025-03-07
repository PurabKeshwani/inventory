import 'package:inventory/src/data/model.dart';

class Displaysandindicators {
  final List<Component> components = [
    Component(name: 'Small O-LED', boxNo: '', stock: 1),
    Component(
        name: '8 digit 7 segment display',
        boxNo: '',
        stock: 0), // Assuming stock is 0 since not provided
    Component(name: '2 digit 7 segment (red colour)', boxNo: '', stock: 1),
    Component(name: '1 digit 7 segment display (Big)', boxNo: '', stock: 2),
    Component(name: '1 digit 7 segment display', boxNo: '', stock: 5),
    Component(name: '3 digit 7 segment', boxNo: '', stock: 4),
    Component(
        name: 'LED matrix',
        boxNo: '',
        stock: 0), // Assuming stock is 0 since not provided
    Component(name: 'RGB LED STRIPS', boxNo: '', stock: 1),
    Component(name: 'IIC OLED SSD1306', boxNo: '', stock: 1),
    Component(name: 'I2C MODULE', boxNo: '', stock: 15),
    Component(name: 'LCD with shield', boxNo: '', stock: 1),
    Component(name: 'LCD 16X2', boxNo: '', stock: 2),
    Component(name: 'LCD 20 x 4', boxNo: '', stock: 5),
    Component(name: 'LCD 3.5 inch', boxNo: '', stock: 5),
    Component(name: 'RFID TAG', boxNo: '', stock: 5),
    Component(name: 'RFID CARD', boxNo: '', stock: 5),
  ];

  Displaysandindicators() {
    print("Initializing Displaysandindicators");
    print("Number of components initialized: ${components.length}");
    components
        .forEach((component) => print("Loaded component: ${component.name}"));
  }
}
