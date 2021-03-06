import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Directory directory;
const MethodChannel channel = MethodChannel('com.tekartik.sqflite');
final List<MethodCall> log = <MethodCall>[];
bool setupDone = false;

Future<void> setup() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (setupDone) {
    return;
  }
  directory = await Directory.systemTemp.createTemp();

  String response;
  channel.setMockMethodCallHandler((MethodCall methodCall) async {
    //print("METHOD CALL: $methodCall");
    log.add(methodCall);
    switch (methodCall.method) {
      case "getDatabasesPath":
        return directory.path;
        break;
      case "query":
        if (methodCall.arguments["sql"] ==
            'SELECT key,value,type,list_type,map_key_type,map_value_type '
                'FROM kvstore WHERE key="k"') {
          final res = <Map<String, dynamic>>[
            <String, dynamic>{
              "key": "k",
              "value": "v",
              "type": "String",
              "list_type": null,
              "map_key_type": null,
              "map_value_type": null
            }
          ];
          return res;
        } else if (methodCall.arguments["sql"] ==
            'SELECT key,value,type,list_type,map_key_type,map_value_type '
                'FROM kvstore WHERE key="k_int"') {
          final res = <Map<String, dynamic>>[
            <String, dynamic>{
              "key": "k_int",
              "value": "1",
              "type": "int",
              "list_type": null,
              "map_key_type": null,
              "map_value_type": null
            }
          ];
          return res;
        } else if (methodCall.arguments["sql"] ==
            'SELECT key,value,type,list_type,map_key_type,map_value_type '
                'FROM kvstore WHERE key="k_double"') {
          final res = <Map<String, dynamic>>[
            <String, dynamic>{
              "key": "k_double",
              "value": "1.0",
              "type": "double",
              "list_type": null,
              "map_key_type": null,
              "map_value_type": null
            }
          ];
          return res;
        } else if (methodCall.arguments["sql"] ==
            'SELECT key,value,type,list_type,map_key_type,map_value_type '
                'FROM kvstore WHERE key="k_list"') {
          final res = <Map<String, dynamic>>[
            <String, dynamic>{
              "key": "k_list",
              "value": "1,2,3",
              "type": "List",
              "list_type": "int",
              "map_key_type": null,
              "map_value_type": null
            }
          ];
          return res;
        } else if (methodCall.arguments["sql"] ==
            'SELECT key,value,type,list_type,map_key_type,map_value_type '
                'FROM kvstore WHERE key="k_map"') {
          final res = <Map<String, dynamic>>[
            <String, dynamic>{
              "key": "k_map",
              "value": '{"1":1,"2":2}',
              "type": "Map",
              "list_type": null,
              "map_key_type": "String",
              "map_value_type": "int"
            }
          ];
          return res;
        } else if (methodCall.arguments["sql"] ==
            'SELECT key,value,type,list_type,map_key_type,map_value_'
                'type FROM kvstore WHERE key="k_bool"') {
          final res = <Map<String, dynamic>>[
            <String, dynamic>{
              "key": "k_bool",
              "value": 'true',
              "type": "bool",
              "list_type": null,
              "map_key_type": null,
              "map_value_type": null
            }
          ];
          return res;
        } else if (methodCall.arguments["sql"] == 'SELECT * FROM kvstore') {
          final res = <Map<String, dynamic>>[<String, dynamic>{}];
          return res;
        }
    }
    return response;
  });
}
