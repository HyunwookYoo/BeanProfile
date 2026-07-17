import 'package:flutter/material.dart';

void main() => runApp(const _Boot());

class _Boot extends StatelessWidget {
  const _Boot();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: Text('BeanProfile'))),
      );
}
