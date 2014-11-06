part of three;

/**
 * @author mrdoob / http://mrdoob.com/
 * @author alteredq / http://alteredqualia.com/
 *
 * Ported to Dart from JS by:
 * @author nelson silva / http://www.inevo.pt/
 *
 * based on r51
 */
class JSONLoader extends Loader {

  JSONLoader({bool showStatus: false}) : super(showStatus);

  load(url, LoadedCallback callback, {texturePath: null}) {

    if (texturePath == null) {
      texturePath = Loader._extractUrlBase(url);
    }

    onLoadStart();

    _loadAjaxJSON(url, callback, texturePath);
  }

  _loadAjaxJSON(String url, LoadedCallback callback, String texturePath, {LoadProgressCallback callbackProgress: null}) {

    HttpRequest xhr = new HttpRequest();

    var length = 0;

    xhr.onReadyStateChange.listen((Event e) {

      if (xhr.readyState == HttpRequest.DONE) {

        if (xhr.status == 200 || xhr.status == 0) {

          if (!xhr.responseText.isEmpty) {

            var json = JSON.decode(xhr.responseText);
            _createModel(json, callback, texturePath);

          } else {

            print("THREE.JSONLoader: [$url] seems to be unreachable or file there is empty");

          }

          // in context of more complex asset initialization
          // do not block on single failed file
          // maybe should go even one more level up

          onLoadComplete();

        } else {

          print("THREE.JSONLoader: Couldn't load [$url] [${xhr.status}]");

        }

      } else if (xhr.readyState == HttpRequest.LOADING) {

        if (callbackProgress != null) {

          if (length == 0) {

            length = xhr.getResponseHeader("Content-Length");

          }

          callbackProgress({
            "total": length,
            "loaded": xhr.responseText.length
          });

        }

      } else if (xhr.readyState == HttpRequest.HEADERS_RECEIVED) {

        length = xhr.getResponseHeader("Content-Length");

      }

    });

    xhr.open("GET", url);
    xhr.send(null);

  }

  bool _isBitSet(value, position) => (value & (1 << position)) > 0;

  _createModel(Map json, LoadedCallback callback, String texturePath) {

    var geometry = new Geometry();
    var scale = (json.containsKey("scale")) ? 1.0 / json["scale"] : 1.0;

    _initMaterials(geometry, json["materials"], texturePath);

    _parseModel(json, geometry, scale);

    _parseSkin(json, geometry);
    _parseMorphing(json, geometry, scale);

    geometry.computeCentroids();
    geometry.computeFaceNormals();

    if (_hasNormals(geometry)) geometry.computeTangents();

    callback(geometry);
  }

  _parseModel(Map json, Geometry geometry, num scale) {

    var i;
    var nUvLayers = 0;
    var colors = json["colors"];
    var normals = json["normals"];
    var vertices = json["vertices"];
    var faces = json["faces"];
    var v;
    var u;
    var uvs;
    var uvLayer;
    var normal;
    var color;
    var face;
    var vertex;
    var hasFaceVertexColor;
    var hasFaceColor;
    var hasFaceVertexNormal;
    var hasFaceNormal;
    var hasFaceVertexUv;
    var hasFaceUv;
    var hasMaterial;
    var isQuad;
    var type;
    var materialIndex;
    var uvIndex;
    var normalIndex;
    var colorIndex;
    var nVertices;
    var zLength;
    var offset;
    var fi;
    var j;

    // disregard empty arrays

    for (i = 0; i < json["uvs"].length; i++) {

      if (!json["uvs"][i].isEmpty) nUvLayers++;

    }

    geometry.faceUvs = new List(nUvLayers);
    geometry.faceVertexUvs = new List(nUvLayers);

    for (i = 0; i < nUvLayers; i++) {

      geometry.faceUvs[i] = new List(faces.length);
      geometry.faceVertexUvs[i] = new List(faces.length);

    }

    offset = 0;
    zLength = vertices.length;

    while (offset < zLength) {

      vertex = new Vector3.zero();

      vertex.x = vertices[offset++] * scale;
      vertex.y = vertices[offset++] * scale;
      vertex.z = vertices[offset++] * scale;

      geometry.vertices.add(vertex);

    }

    offset = 0;
    zLength = faces.length;

    while (offset < zLength) {

      type = faces[offset++];


      isQuad = _isBitSet(type, 0);
      hasMaterial = _isBitSet(type, 1);
      hasFaceUv = _isBitSet(type, 2);
      hasFaceVertexUv = _isBitSet(type, 3);
      hasFaceNormal = _isBitSet(type, 4);
      hasFaceVertexNormal = _isBitSet(type, 5);
      hasFaceColor = _isBitSet(type, 6);
      hasFaceVertexColor = _isBitSet(type, 7);

      //console.log("type", type, "bits", isQuad, hasMaterial, hasFaceUv, hasFaceVertexUv, hasFaceNormal, hasFaceVertexNormal, hasFaceColor, hasFaceVertexColor);

      if (isQuad) {

        face = new Face4();

        face.a = faces[offset++];
        face.b = faces[offset++];
        face.c = faces[offset++];
        face.d = faces[offset++];

        nVertices = 4;

      } else {

        face = new Face3();

        face.a = faces[offset++];
        face.b = faces[offset++];
        face.c = faces[offset++];

        nVertices = 3;

      }

      if (hasMaterial) {

        materialIndex = faces[offset++];
        face.materialIndex = materialIndex;

      }

      // to get face <=> uv index correspondence

      fi = geometry.faces.length;

      if (hasFaceUv) {

        for (i = 0; i < nUvLayers; i++) {

          uvLayer = json["uvs"][i];

          uvIndex = faces[offset++];

          u = uvLayer[uvIndex * 2];
          v = uvLayer[uvIndex * 2 + 1];

          geometry.faceUvs[i][fi] = new UV(u, v);

        }

      }

      if (hasFaceVertexUv) {

        for (i = 0; i < nUvLayers; i++) {

          uvLayer = json["uvs"][i];

          uvs = new List(nVertices);

          for (j = 0; j < nVertices; j++) {

            uvIndex = faces[offset++];

            u = uvLayer[uvIndex * 2];
            v = uvLayer[uvIndex * 2 + 1];

            uvs[j] = new UV(u, v);

          }

          geometry.faceVertexUvs[i][fi] = uvs;

        }

      }

      if (hasFaceNormal) {

        normalIndex = faces[offset++] * 3;

        normal = new Vector3.zero();

        normal.x = normals[normalIndex++];
        normal.y = normals[normalIndex++];
        normal.z = normals[normalIndex];

        face.normal = normal;

      }

      if (hasFaceVertexNormal) {

        for (i = 0; i < nVertices; i++) {

          normalIndex = faces[offset++] * 3;

          normal = new Vector3.zero();

          normal.x = normals[normalIndex++];
          normal.y = normals[normalIndex++];
          normal.z = normals[normalIndex];

          face.vertexNormals.add(normal);

        }

      }


      if (hasFaceColor) {

        colorIndex = faces[offset++];

        color = new Color(colors[colorIndex]);
        face.color = color;

      }


      if (hasFaceVertexColor) {

        for (i = 0; i < nVertices; i++) {

          colorIndex = faces[offset++];

          color = new Color(colors[colorIndex]);
          face.vertexColors.add(color);

        }

      }

      geometry.faces.add(face);

    }

  }

  _parseSkin(Map json, Geometry geometry) {

    var i;
    var d;
    var c;
    var b;
    var a;
    var w;
    var z;
    var y;
    var x;
    var l;

    if (json.containsKey("skinWeights")) {

      l = json["skinWeights"].length;
      for (i = 0; i < l; i += 2) {

        x = json["skinWeights"][i];
        y = json["skinWeights"][i + 1];
        z = 0.0;
        w = 0.0;

        geometry.skinWeights.add(new Vector4(x, y, z, w));

      }

    }

    if (json.containsKey("skinIndices")) {

      l = json["skinIndices"].length;
      for (i = 0; i < l; i += 2) {

        a = json["skinIndices"][i];
        b = json["skinIndices"][i + 1];
        c = 0.0;
        d = 0.0;

        geometry.skinIndices.add(new Vector4(a, b, c, d));

      }

    }

    geometry.bones = json["bones"];
    geometry.animation = json["animation"];

  }

  _parseMorphing(Map json, Geometry geometry, num scale) {

    if (json.containsKey("morphTargets")) {

      var i;
      var srcVertices;
      var dstVertices;
      var vl;
      var v;
      var l;

      geometry.morphTargets = new List(json["morphTargets"].length);

      for (i = 0; i < geometry.morphTargets.length; i++) {

        geometry.morphTargets[i] = new MorphTarget(name: json["morphTargets"][i]["name"], vertices: []);

        dstVertices = geometry.morphTargets[i].vertices;
        srcVertices = json["morphTargets"][i]["vertices"];

        vl = srcVertices.length;
        for (v = 0; v < vl; v += 3) {

          var vertex = new Vector3.zero();
          vertex.x = srcVertices[v] * scale;
          vertex.y = srcVertices[v + 1] * scale;
          vertex.z = srcVertices[v + 2] * scale;

          dstVertices.add(vertex);

        }

      }

    }

    if (json.containsKey("morphColors")) {

      var i;
      var color;
      var srcColors;
      var dstColors;
      var cl;
      var c;
      var l;

      geometry.morphColors = new List(json["morphColors"].length);

      for (i = 0; i < geometry.morphColors.length; i++) {

        dstColors = [];
        srcColors = json["morphColors"][i]["colors"];

        cl = srcColors.length;
        for (c = 0; c < cl; c += 3) {

          color = new Color(0xffaa00);
          color.setRGB(srcColors[c], srcColors[c + 1], srcColors[c + 2]);
          dstColors.add(color);

        }

        geometry.morphColors[i] = new MorphColors(name: json["morphColors"][i]["name"], colors: dstColors);
      }
    }
  }

}
