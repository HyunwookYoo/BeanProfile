import 'package:flutter/material.dart';

class BeanDetailScreen extends StatelessWidget {
  const BeanDetailScreen({super.key, required this.beanId});
  final int beanId;
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('원두 상세')));
}
