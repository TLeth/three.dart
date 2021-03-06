part of three;

/**
 * @author mr.doob / http://mrdoob.com/
 *
 * Ported to Dart from JS by:
 * @author rob silverton / http://www.unwrong.com/
 */

class PointLight extends Light {
  Vector3 _position;
  num intensity;
  num distance;

  PointLight(num hex, {this.intensity: 1, this.distance: 0}) : super(hex) {
    //THREE.Light.call( this, hex );

    _position = new Vector3.zero();
  }
}
