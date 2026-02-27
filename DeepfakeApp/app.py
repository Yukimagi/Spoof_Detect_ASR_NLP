from flask import Flask, request, jsonify
from sincnet_tensorflow import SincConv1D, LayerNorm
import os
import numpy as np
import librosa
from tensorflow.keras.models import load_model
from tensorflow.keras.layers import Layer
import tensorflow as tf

current_directory = os.getcwd()
print("Current working directory:", current_directory)

# 定義自定義層，將預強調功能整合進來
class PreEmphasisLayer(Layer):
    def __init__(self, coef=0.97, **kwargs):
        super(PreEmphasisLayer, self).__init__()
        self.coef = coef

    def call(self, inputs):
        emphasized_signal = inputs[:, 1:] - self.coef * inputs[:, :-1]
        return tf.concat([inputs[:, :1], emphasized_signal], axis=1)

    def get_config(self):
        config = {'coef': self.coef}
        base_config = super().get_config()
        return dict(list(base_config.items()) + list(config.items()))

# 定義音頻資料長度統一的函數
def pad(x, max_len=64600):
    x_len = len(x)
    if (x_len >= max_len):
        return x[:max_len]
    num_repeats = int(max_len / x_len) + 1
    padded_x = np.tile(x, (1, num_repeats))[:, :max_len][0]
    return padded_x

app = Flask(__name__)

# 設置上傳資料夾
app.config['UPLOAD_FOLDER'] = 'uploads'
if not os.path.exists(app.config['UPLOAD_FOLDER']):
    os.makedirs(app.config['UPLOAD_FOLDER'])

# 確保模型檔案存在
model_path = "Res2Net.h5"
if not os.path.exists(model_path):
    raise FileNotFoundError("Model file not found")

# 載入模型
custom_objects = {'SincConv1D': SincConv1D, 'LayerNorm': LayerNorm, 'PreEmphasisLayer': PreEmphasisLayer}
model = load_model(model_path, custom_objects=custom_objects)

@app.route('/predict', methods=['POST'])
def predict():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    if file:
        filename = os.path.join(app.config['UPLOAD_FOLDER'], file.filename)
        file.save(filename)

        # 載入音頻
        audio, sr = librosa.load(filename, mono=True, sr=None)
        audio = pad(x=audio)
        X = audio.reshape(1, audio.shape[0], 1)

        # 預測
        pred = model.predict(X)
        pred_classes = np.argmax(pred, axis=1)
        if pred_classes == 0:
            result = "真音"
        else:
            result = "假音"

        return jsonify({"message": "success", "result": result})

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8000, debug=True)
