from flask import Flask, request, jsonify
import os
import numpy as np
import librosa
import tensorflow as tf
import time

# 定義音頻資料長度統一的函數
def pad(x, max_len=64600):
    x_len = len(x)
    if (x_len >= max_len):
        return x[:max_len]
    # 需要填充
    num_repeats = int(max_len / x_len) + 1
    padded_x = np.tile(x, (1, num_repeats))[:, :max_len][0]
    return padded_x

app = Flask(__name__)

# 設置上傳資料夾
app.config['UPLOAD_FOLDER'] = 'uploads'
if not os.path.exists(app.config['UPLOAD_FOLDER']):
    os.makedirs(app.config['UPLOAD_FOLDER'])


# 確保模型檔案存在
model_path = "quantized_Res2Net.tflite"
if not os.path.exists(model_path):
    raise FileNotFoundError("Model file not found")
# 加載模型(量化)
interpreter = tf.lite.Interpreter(model_path)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

@app.route('/predict', methods=['POST'])
def predict():
    if 'files' not in request.files:
        return jsonify({'error': 'No files part'}), 400
    files = request.files.getlist('files')
    if len(files) == 0:
        return jsonify({'error': 'No selected files'}), 400
    
    results = []
    total_time = 0
    num_files = len(files)
    '''
    # 確保模型檔案存在
    model_path = "quantized_Res2Net.tflite"
    if not os.path.exists(model_path):
        return jsonify({'error': 'Model file not found'}), 500
    # 加載模型(量化)
    interpreter = tf.lite.Interpreter(model_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    '''

    for i, file in enumerate(files):
        filename = os.path.join(app.config['UPLOAD_FOLDER'], file.filename)
        file.save(filename)

        # 開始時間
        start_time = time.time()
        # 載入音頻
        audio, sr = librosa.load(filename, mono=True, sr=None)
        audio = pad(x=audio)
        X = audio.reshape(1, 64600, 1).astype(np.float32)  # 確保數據類型為 float32

        interpreter.set_tensor(input_details[0]['index'], X)  # 使用重塑後的 X

        # 預測
        interpreter.invoke()
        # 結束時間
        end_time = time.time()

        predict_time = end_time - start_time
        total_time += predict_time

        output_data = interpreter.get_tensor(output_details[0]['index'])
        p0 = output_data[:, 0]
        p1 = output_data[:, 1]

        predictions = np.where(p0 > p1, 0, 1)

        for j, prediction in enumerate(predictions):
            if prediction == 0:
                result = f'真音'
                # result = f'第{i+1}筆預測完成, 樣本為真音, 推理時間: {predict_time:.4f} 秒'
            else:
                result = f'假音'
                # result = f'第{i+1}筆預測完成, 樣本為假音, 推理時間: {predict_time:.4f} 秒'	
            results.append(result)

    avg_time = total_time / num_files
    # results.append(f'全部的平均預測時間為: {avg_time:.4f} 秒')

    return jsonify({"message": "success", "results": results})

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8000, debug=True)
