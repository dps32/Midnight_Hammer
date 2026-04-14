class InputState {
  final Set<int> _pressedKeys = <int>{};
  final Set<int> _justPressedKeys = <int>{};

  bool _justTouched = false;
  bool _touchDown = false;
  double _x = 0;
  double _y = 0;
  double _scrollY = 0;

  void onKeyDown(int keycode) {
    if (!_pressedKeys.contains(keycode)) {
      _justPressedKeys.add(keycode);
    }
    _pressedKeys.add(keycode);
  }

  void onKeyUp(int keycode) {
    _pressedKeys.remove(keycode);
  }

  bool isKeyPressed(int keycode) => _pressedKeys.contains(keycode);

  bool isKeyJustPressed(int keycode) => _justPressedKeys.contains(keycode);

  void onPointerDown(double x, double y) {
    _x = x;
    _y = y;
    _touchDown = true;
    _justTouched = true;
  }

  void onPointerMove(double x, double y) {
    _x = x;
    _y = y;
  }

  void onPointerUp(double x, double y) {
    _x = x;
    _y = y;
    _touchDown = false;
  }

  void onPointerScroll(double scrollY) {
    _scrollY += scrollY;
  }

  bool justTouched() => _justTouched;

  int getX() => _x.round();

  int getY() => _y.round();

  bool isTouchDown() => _touchDown;

  double consumeScrollY() {
    final double value = _scrollY;
    _scrollY = 0;
    return value;
  }

  void endFrame() {
    _justPressedKeys.clear();
    _justTouched = false;
  }
}
