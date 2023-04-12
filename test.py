import pandas as pd
import numpy as np
import tensorflow as tf
import random

df = pd.read_csv("new.csv")
y = df["price"]
x = df.drop(["price"], axis=1)

num_hidden_layers = random.randint(1,5)
seq = []
seq.append(tf.keras.layers.Dense(units=12))
hidden_nodes = []
for i in range(num_hidden_layers):
    seq.append(tf.keras.layers.Dense(units=random.randint(20,100)))
seq.append(tf.keras.layers.Dense(units=1))
lr = random.random()*0.001

f = open("e.txt", "r")
e = int(f.read())
f.close()


model = tf.keras.Sequential(seq)
model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=lr), loss='mean_absolute_error')
history = model.fit(x,y,epochs=e,verbose=0)
f = open("loss.txt", "w")
for i in history.history['loss']:
	f.write(str(i) + "\n")	
f.close()
