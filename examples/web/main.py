from kivy.app import App
from kivy.lang import Builder
from kivy.properties import NumericProperty

KV = '''
BoxLayout:
    orientation: 'vertical'
    padding: dp(24)
    spacing: dp(12)
    canvas.before:
        Color:
            rgba: .12, .14, .18, 1
        Rectangle:
            pos: self.pos
            size: self.size
    Label:
        text: 'Kivy on WebAssembly'
        font_size: sp(32)
        bold: True
    Widget:
        canvas:
            Color:
                hsv: (app.count * .07) % 1, .6, .9
            Ellipse:
                pos: self.center_x - dp(40), self.center_y - dp(40)
                size: dp(80), dp(80)
            Color:
                rgba: 1, 1, 1, .8
            Line:
                rounded_rectangle: self.x + dp(4), self.y + dp(4), self.width - dp(8), self.height - dp(8), dp(12)
                width: dp(1.5)
    Button:
        text: 'Pressed {} times'.format(app.count)
        size_hint_y: None
        height: dp(48)
        on_release: app.count += 1
    Slider:
        id: slider
        size_hint_y: None
        height: dp(40)
        value: 40
    ProgressBar:
        value: slider.value
        size_hint_y: None
        height: dp(20)
    TextInput:
        hint_text: 'type here'
        size_hint_y: None
        height: dp(44)
        multiline: False
'''


class WebApp(App):
    count = NumericProperty(0)

    def build(self):
        return Builder.load_string(KV)


WebApp().run()
