part of three;

/**
 * @author mr.doob / http://mrdoob.com/
 * @author mikael emtinger / http://gomo.se/
 * @author alteredq / http://alteredqualia.com/
 *
 * Ported to Dart from JS by:
 * @author rob silverton / http://www.unwrong.com/
 */

abstract class GeometryObject {

}
//get _hasGeometry => (object i;
class Object3D {

  int id;
  String name;
  Map properties;

  Object3D parent;
  List children;

  Vector3 up;
  Vector3 position;
  Vector3 rotation;
  Vector3 scale;

  String eulerOrder;

  bool _dynamic;
  bool doubleSided;
  bool flipSided;
  bool rotationAutoUpdate;

  int renderDepth;

  Matrix4 matrix;
  Matrix4 matrixWorld;
  Matrix4 matrixRotationWorld;

  bool matrixAutoUpdate = false;
  bool matrixWorldNeedsUpdate = false;

  var quaternion;
  bool useQuaternion;

  num boundRadius;
  num boundRadiusScale;

  bool visible = false;
  bool castShadow = false;
  bool receiveShadow = false;
  bool frustumCulled = false;

  Vector3 _vector;

  var customDepthMaterial;

  // TODO : Introduce a mixin for objects with Geometry
  Geometry geometry;

  // TODO : Introduce a mixin for objects with Material
  Material material;

  // WebGL
  bool __webglInit = false;
  bool __webglActive = false;
  var immediateRenderCallback;

  Matrix4 _modelViewMatrix;
  Matrix3 _normalMatrix;

  int count;
  bool hasPositions;
  bool hasNormals;
  bool hasUvs;
  bool hasColors;
  var positionArray;
  var normalArray;
  var uvArray;
  var colorArray;
  gl.Buffer __webglVertexBuffer;
  gl.Buffer __webglNormalBuffer;
  gl.Buffer __webglUVBuffer;
  gl.Buffer __webglColorBuffer;

  var __webglMorphTargetInfluences;

  Object3D()
      : id = Object3DCount++,

        name = '',
        properties = {},

        parent = null,
        children = [],

        up = new Vector3(0.0, 1.0, 0.0),

        position = new Vector3(0.0, 0.0, 0.0),
        rotation = new Vector3(0.0, 0.0, 0.0),
        eulerOrder = 'XYZ',
        scale = new Vector3(1.0, 1.0, 1.0),

        renderDepth = null,

        rotationAutoUpdate = true,

        matrix = new Matrix4.identity(),
        matrixWorld = new Matrix4.identity(),
        matrixRotationWorld = new Matrix4.identity(),

        matrixAutoUpdate = true,
        matrixWorldNeedsUpdate = true,

        quaternion = new Quaternion.identity(),
        useQuaternion = false,

        boundRadius = 0.0,
        boundRadiusScale = 1.0,

        visible = true,

        castShadow = false,
        receiveShadow = false,

        frustumCulled = true,

        _vector = new Vector3.zero();

  // TODO - These are not in three.js
  //_dynamic = false, // when true it retains arrays so they can be updated with __dirty*

  //doubleSided = false,
  //flipSided = false,

  // dynamic
  bool get isDynamic => _dynamic;
  set isDynamic(bool flag) => _dynamic = flag;

  void applyMatrix(Matrix4 matrix) {
    this.matrix = matrix * this.matrix;

    this.scale = getScaleFromMatrix(this.matrix);

    Matrix4 mat = extractRotation(new Matrix4.identity(), this.matrix);
    this.rotation = calcEulerFromRotationMatrix(mat, this.eulerOrder);

    this.position = this.matrix.getTranslation();
  }

  void translate(double distance, Vector3 axis) {
    matrix.rotate3(axis);
    axis.normalize();
    position.add(axis.scale(distance));
  }

  void translateX(double distance) => translate(distance, _vector.setValues(1.0, 0.0, 0.0));

  void translateY(double distance) => translate(distance, _vector.setValues(0.0, 1.0, 0.0));

  void translateZ(double distance) => translate(distance, _vector.setValues(0.0, 0.0, 1.0));

  void lookAt(Vector3 vector) {
    // TODO: Add hierarchy support.

    makeLookAt(matrix, vector, position, up);

    if (rotationAutoUpdate) {
      if (useQuaternion) quaternion.setFromRotationMatrix(matrix); else rotation = calcEulerFromRotationMatrix(matrix, eulerOrder);
    }
  }

  void add(Object3D object) {
    if (object == this) {
      print('THREE.Object3D.add: An object can\'t be added as a child of itself.');
      return;
    }


    if (object.parent != null) {
      object.parent.remove(object);
    }

    object.parent = this;
    children.add(object);

    // add to scene
    Object3D scene = this;

    while (scene.parent != null) {
      scene = scene.parent;
    }

    if (scene is Scene) {
      (scene as Scene).addObject(object);
    }

  }

  void remove(Object3D object) {

    int index = children.indexOf(object);

    if (index != -1) {

      object.parent = null;
      children.removeAt(index);

      // remove from scene
      Object3D obj = this;

      while (obj.parent != null) {
        obj = obj.parent;
      }

      if (obj is Scene) {
        (obj as Scene).removeObject(object);
      }
    }
  }

  Object3D getChildByName(String name, bool doRecurse) {
    int c;
    int cl = children.length;
    Object3D child;
    Object3D recurseResult;

    children.forEach((child) {

      if (child.name == name) {
        return child;
      }

      if (doRecurse) {
        recurseResult = child.getChildByName(name, doRecurse);

        if (recurseResult != null) {
          return recurseResult;
        }
      }
    });

    return null;
  }

  void updateMatrix() {

    if (useQuaternion) {
      setRotationFromQuaternion(matrix, quaternion);
    } else {
      setRotationFromEuler(matrix, rotation, eulerOrder);
    }

    matrix.setTranslation(position);

    if (scale.x != 1.0 || scale.y != 1.0 || scale.z != 1.0) {
      matrix.scale(scale);
      boundRadiusScale = Math.max(scale.x, Math.max(scale.y, scale.z));
    }

    matrixWorldNeedsUpdate = true;
  }

  void updateMatrixWorld({bool force: false}) {

    if (matrixAutoUpdate) updateMatrix();

    // update matrixWorld
    if (matrixWorldNeedsUpdate || force) {
      if (parent != null) {
        matrixWorld = parent.matrixWorld * matrix;
      } else {
        matrixWorld = matrix.clone();
      }

      matrixWorldNeedsUpdate = false;

      force = true;
    }

    // update children
    children.forEach((c) => c.updateMatrixWorld(force: force));

  }

  worldToLocal(Vector3 vector) {
    Matrix4 m = this.matrixWorld.clone();
    m.invert();
    m.transform3(vector);
  }

  localToWorld(Vector3 vector) => vector.applyProjection(matrixWorld);

  clone() {

    // TODO

  }

  static Matrix4 ___m1;
  static Matrix4 get __m1 {
    if (___m1 == null) {
      ___m1 = new Matrix4.identity();
    }
    return ___m1;
  }
}
