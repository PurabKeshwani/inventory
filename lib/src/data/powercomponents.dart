import 'package:inventory/src/data/model.dart';

class Powercomponents {
  List<Component> components = [
    Component(name: 'Voltage regulator (LM7812C)', boxNo: '', stock: 2),
    Component(
        name: '1A Bridge Rectifier',
        boxNo: '',
        stock: 0), // Assuming stock is 0 since not provided
    Component(
        name: 'Power Switch Dip k',
        boxNo: '',
        stock: 0), // Assuming stock is 0 since not provided
    Component(
        name: 'HW-221 Voltage Converter',
        boxNo: '',
        stock: 0), // Assuming stock is 0 since not provided
    Component(
        name: 'Solar panel 5V, 6V, 10V',
        boxNo: '',
        stock: 0), // Assuming stock is 0 since not provided
    Component(name: 'battery 9v', boxNo: '', stock: 5),
    Component(name: 'Charger', boxNo: '', stock: 5),
    Component(name: 'PWM Motor Driver', boxNo: '', stock: 5),
  ];
}
