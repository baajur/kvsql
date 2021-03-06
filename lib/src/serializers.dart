import 'dart:convert';
import 'package:flutter/material.dart';

import 'exceptions.dart';

/// encoding format for database row reprensentation
class DatabaseEncodedRow {
  /// default constructor
  DatabaseEncodedRow(
      {@required this.value,
      @required this.type,
      this.listType,
      this.mapKeyType,
      this.mapValueType});

  /// the type
  final String type;

  /// the value
  final String value;

  /// the type of a list
  final String listType;

  /// the type of a map key
  final String mapKeyType;

  /// the type of a map value
  final String mapValueType;
}

List<String> _inferMapTypeToString<T>() {
  final bs = T.toString();
  final t = bs.replaceFirst("Map<", "");
  if (t.contains("Map")) {
    throw InvalidTypeException("A map value can not be another map");
  }
  final l = t.split(",");
  if (l[1].contains("List")) {
    throw InvalidTypeException("A map value can not be a list");
  }
  l[1] = l[1].replaceAll(">", "");
  final k = l[0].trim();
  final v = l[1].trim();
  return <String>[k, v];
}

String _inferListTypeToString<T>() {
  final bs = T.toString();
  final t = bs.replaceFirst("List<", "");
  if (t.contains("List")) {
    throw InvalidTypeException("A list value type can not be another list");
  } else if (t.contains("Map")) {
    throw InvalidTypeException("A list value type can not be a map");
  }
  return t.replaceFirst(">", "");
}

/// Encode a value to be stored as a string
DatabaseEncodedRow encode<T>(T value) {
  String val;
  String typeStr;
  String listTypeStr = "NULL";
  String mapKeyTypeStr = "NULL";
  String mapValueTypeStr = "NULL";
  if (value == null) {
    val = null;
    typeStr = "unknown";
    return DatabaseEncodedRow(value: val, type: typeStr);
  } else {
    if (value is String) {
      val = value.toString();
      typeStr = "String";
    } else if (value is int) {
      val = "${int.parse(value.toString())}";
      typeStr = "int";
    } else if (value is double) {
      val = "${double.parse(value.toString())}";
      typeStr = "double";
    } else if (value is bool) {
      val = "$value";
      typeStr = "bool";
    } else if (value is List) {
      val = value.join(",");
      typeStr = "List";
      listTypeStr = _inferListTypeToString<T>();
    } else if (value is Map) {
      final strMap = <String, dynamic>{};
      value.forEach((dynamic k, dynamic v) {
        strMap["$k"] = v;
      });
      val = json.encode(strMap);
      typeStr = "Map";
      final res = _inferMapTypeToString<T>();
      mapKeyTypeStr = res[0];
      mapValueTypeStr = res[1];
    }
  }
  //print(
  //    "$typeStr / List: $listTypeStr / mk: $mapKeyTypeStr / mv: $mapValueTypeStr");
  return DatabaseEncodedRow(
      value: val,
      type: typeStr,
      listType: listTypeStr,
      mapKeyType: mapKeyTypeStr,
      mapValueType: mapValueTypeStr);
}

/// Decode a database value to it's type
T decodeFromTypeStr<T>(dynamic value, String typeStr, String listTypeStr,
    String mapKeyTypeStr, String mapValueTypeStr) {
  if (value == "NULL" || value == null) {
    return null;
  }
  dynamic val;
  switch (typeStr) {
    case "String":
      try {
        val = _decodeString(value);
      } catch (e) {
        rethrow;
      }
      break;
    case "int":
      try {
        val = _decodeInt(value);
      } catch (e) {
        rethrow;
      }
      break;
    case "double":
      try {
        val = _decodeDouble(value);
      } catch (e) {
        rethrow;
      }
      break;
    case "bool":
      try {
        val = _decodeBool(value);
      } catch (e) {
        rethrow;
      }
      break;
    case "List":
      try {
        switch (listTypeStr) {
          case "String":
            val = _decodeList<String>(value);
            break;
          case "int":
            val = _decodeList<int>(value);
            break;
          case "double":
            val = _decodeList<double>(value);
            break;
          case "bool":
            val = _decodeList<bool>(value);
            break;
          case "dynamic":
            val = _decodeList<dynamic>(value);
            break;
          default:
            throw InvalidTypeException("Invalid list type $listTypeStr");
        }
      } catch (e) {
        rethrow;
      }
      break;
    case "Map":
      try {
        switch (mapKeyTypeStr) {
          case "String":
            switch (mapValueTypeStr) {
              case "String":
                val = _decodeMap<String, String>(value);
                break;
              case "double":
                val = _decodeMap<String, double>(value);
                break;
              case "int":
                val = _decodeMap<String, int>(value);
                break;
              case "bool":
                val = _decodeMap<String, bool>(value);
                break;
              case "dynamic":
                val = _decodeMap<String, dynamic>(value);
                break;
              default:
                throw InvalidTypeException("Invalid map value type");
            }
            break;
          case "int":
            switch (mapValueTypeStr) {
              case "String":
                val = _decodeMap<int, String>(value);
                break;
              case "double":
                val = _decodeMap<int, double>(value);
                break;
              case "int":
                val = _decodeMap<int, int>(value);
                break;
              case "bool":
                val = _decodeMap<int, bool>(value);
                break;
              case "dynamic":
                val = _decodeMap<int, dynamic>(value);
                break;
              default:
                throw InvalidTypeException("Invalid map value type");
            }
            break;
          case "double":
            switch (mapValueTypeStr) {
              case "String":
                val = _decodeMap<double, String>(value);
                break;
              case "double":
                val = _decodeMap<double, double>(value);
                break;
              case "int":
                val = _decodeMap<double, int>(value);
                break;
              case "bool":
                val = _decodeMap<double, bool>(value);
                break;
              case "dynamic":
                val = _decodeMap<double, dynamic>(value);
                break;
              default:
                throw InvalidTypeException("Invalid map value type");
            }
            break;
          default:
            throw InvalidTypeException("Invalid map key type");
        }
      } catch (e) {
        rethrow;
      }
      break;
    default:
      throw UnknownValueException(
          "Type string $typeStr not known for value $value");
  }
  if (T != dynamic) {
    if (!(val is T)) {
      throw WrongWalueTypeException(
          "Value is of type ${val.runtimeType} and should be $T");
    }
  }
  final endVal = val as T;
  return endVal;
}

String _decodeString(dynamic value) {
  return "$value";
}

bool _decodeBool(dynamic value) {
  bool res;
  switch (value == "true") {
    case true:
      res = true;
      break;
    case false:
      res = false;
      break;
    default:
      throw WrongWalueTypeException("Wrong value for boolean: $value");
  }
  return res;
}

int _decodeInt(dynamic value) {
  int val;
  try {
    val = int.parse(value.toString());
  } catch (e) {
    throw InvalidTypeException("Can not parse integer $value");
  }
  return val;
}

double _decodeDouble(dynamic value) {
  double val;
  try {
    val = double.parse(value.toString());
  } catch (e) {
    throw InvalidTypeException("Can not parse integer $value");
  }
  return val;
}

List<T> _decodeList<T>(dynamic value) {
  final val = <T>[];
  if (value == "") {
    // empty list
    return val;
  }
  try {
    final decoded = value.toString().split(",");
    decoded.forEach((String el) {
      if (T == String) {
        val.add(el as T);
      } else if (T == int) {
        val.add(_decodeInt(el) as T);
      } else if (T == double) {
        val.add(_decodeDouble(el) as T);
      } else if (T == bool) {
        val.add(_decodeBool(el) as T);
      } else if (T == dynamic) {
        val.add(el as T);
      }
    });
  } catch (e) {
    throw DecodingException("Can not decode list value $value");
  }
  //print("VAL $val");
  return val;
}

Map<K, V> _decodeMap<K, V>(dynamic value) {
  var val = <K, V>{};
  try {
    final jsonDecoded = json.decode(value.toString()) as Map<String, dynamic>;
    val = Map<K, V>.from(jsonDecoded);
  } catch (e) {
    throw DecodingException("Can not decode map $value");
  }
  return val;
}
