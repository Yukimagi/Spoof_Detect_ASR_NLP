from tensorflow.keras.layers import Layer
# 定義自定義層，將預強調功能整合進來
class PreEmphasisLayer(Layer):
    def __init__(self, coef=0.97,**kwargs):
        super(PreEmphasisLayer, self).__init__()
        self.coef = coef

    def call(self, inputs):
        emphasized_signal = inputs[:, 1:] - self.coef * inputs[:, :-1]
        return tf.concat([inputs[:, :1], emphasized_signal], axis=1)   

    def get_config(self):
        config = {'coef': self.coef}
        base_config = super().get_config()
        return dict(list(base_config.items()) + list(config.items()))   

from flask import Flask, render_template, request, jsonify
from sincnet_tensorflow import SincConv1D, LayerNorm
import os
import shutil
import pandas as pd
import numpy as np
import librosa 
import librosa.display
import soundfile as sf
import matplotlib.pyplot as plt
import IPython.display as ipd
from tqdm.notebook import tqdm
import tensorflow as tf
import warnings
warnings.filterwarnings("ignore")
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.models import load_model
from sklearn.metrics import accuracy_score
from pydub import AudioSegment


# 定義音頻資料長度統一的函數
def pad(x, max_len=64600):
    x_len = len(x)
    if x_len >= max_len:
        return x[:max_len]
    # need to pad
    num_repeats = int(max_len / x_len)+1
    padded_x = np.tile(x, (1, num_repeats))[:, :max_len][0]
    return padded_x

def convert_to_wav(file_path):
    audio = AudioSegment.from_file(file_path)
    converted_path = file_path.replace(".wav", "_converted.wav")
    audio.export(converted_path, format="wav")
    return converted_path

app = Flask(__name__)

# 設置靜態資料夾的路徑
app.config['UPLOAD_FOLDER'] = '/static'

@app.route('/loading.html')
def loading():
    return render_template("loading.html")

@app.route("/index.html")
def index():
    return render_template("index.html")

@app.route("/about.html")
def about():
    return render_template("about.html")

@app.route("/contact.html")
def contact():
    return render_template("contact.html")

@app.route("/project_sample.html")
def project_sample():
    return render_template("project_sample.html")

@app.route("/user_testing.html")
def user_testing():
    return render_template("user_testing.html")

@app.route("/recording.html")
def recording():
    return render_template("recording.html")

@app.route('/upload1', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return 'No file part'
    file = request.files['file']
    if file.filename == '':
        return 'No selected file'
    if file:
        filename = file.filename
        # 將檔案保存到靜態資料夾中
        print(os.path.join(app.root_path, 'static\\test.flac'))
        file.save(os.path.join(app.root_path, 'static\\test.flac'))
        return 'File uploaded successfully'
    
@app.route('/upload2', methods=['POST'])
def upload_file2():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    if file:
    # 保存文件
        file.save(os.path.join(app.root_path, 'static\\check.wav'))
        return jsonify({'message': 'File uploaded successfully'}), 200

@app.route("/")
def root():
    return render_template("project_sample.html")


@app.route("/submit",methods=["GET", "POST"])
def submit():
    #由于POST、GET獲取資料的方式不同，需要使用if陳述句進行判斷
    if request.method == "POST":
        # 從前端拿數據
        res = request.form.get("path")
    if request.method == "GET":
        res = request.args.get("path")

    #載入模型
    custom_objects = {'SincConv1D': SincConv1D,'LayerNorm': LayerNorm, 'PreEmphasisLayer':PreEmphasisLayer}
    model = load_model("./範例用/Res2Net.h5", custom_objects=custom_objects)
    #載入樣本

    sample_audio_path = res #示範

    # sample_audio_path = convert_to_wav(sample_audio_path)
    
    audio, sr = librosa.load(sample_audio_path, mono=True, sr=None)

    #將音頻長度統一至6秒(16000*6)
    audio = pad(x=audio)
    X = audio.reshape(1,audio.shape[0],1)
    
    pred = model.predict(X)
    pred_classes = np.argmax(pred, axis=1)
    if pred_classes == 0:
        rest = "真音"
    else:
        rest = "假音"
    if len("path") == 0 :
        # 回傳的形式為 json
        return {'message':"error!"}
    else:
        return { "message":"success!","rest":rest}
if __name__ == '__main__':
    #定義app在8080埠運行
    app.run(host="localhost",port=8000,debug=True)
