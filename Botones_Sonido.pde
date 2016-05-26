import controlP5.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import ddf.minim.ugens.*;
import java.util.*;
import java.net.InetAddress;
import javax.swing.*;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;
import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.action.index.IndexResponse;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;

ControlP5 boton;
Minim minim;
AudioPlayer sonido;
FilePlayer son;
AudioMetaData datos;
AudioOutput output;
HighPassSP hpf;
LowPassSP lpf;
Convolver lp;
FFT fftLin;
FFT fftLog;
float spectrumScale = 4;
String archivo;
int a = 0, altura = 350;
String[] direcciones;
boolean suena=false, high=false, low=false, con=false;
float volumen=0;
static String INDEX_NAME = "canciones";
static String DOC_TYPE = "cancion";
ScrollableList list;
Client client;
Node node;
PImage fon1, fon;

void setup() {
  size(600, 400);
  direcciones = new String[100];
  boton = new ControlP5(this);
  boton.addButton("Play")
    .setValue(0)
    .setPosition(70, 370)
    .setFont(createFont("arial", 10))
    .setSize(55, 20);
  boton.addButton("Pausa")
    .setValue(0)
    .setPosition(10, 370)
    .setFont(createFont("arial", 10))
    .setSize(55, 20);
  boton.addButton("Parar")
    .setValue(0)
    .setPosition(130, 370)
    .setFont(createFont("arial", 10))
    .setSize(55, 20);
  boton.addButton("Mas")
    .setValue(0)
    .setPosition(190, 370)
    .setFont(createFont("arial", 10))
    .setSize(55, 20);
  boton.addButton("Menos")
    .setValue(0)
    .setPosition(250, 370)
    .setFont(createFont("arial", 10))
    .setSize(55, 20);
  boton.addButton("importFiles")
    .setPosition(310, 370)
    .setFont(createFont("arial", 10))
    .setLabel("Agregar"+"\n"+"Archivos")
    .setSize(65, 20);
  boton.addButton("HighPass")
    .setPosition(380, 370)
    .setFont(createFont("arial", 10))
    .setSize(55, 20);
  boton.addButton("LowPass")
    .setPosition(440, 370)
    .setFont(createFont("arial", 10))
    .setSize(55, 20);
  boton.addButton("Convoler")
    .setPosition(500, 370)
    .setFont(createFont("arial", 10))
    .setSize(55, 20);

  minim = new Minim(this);
  Settings.Builder settings = Settings.settingsBuilder();
  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);
  node = NodeBuilder.nodeBuilder()
    .settings(settings)
    .clusterName("mycluster")
    .data(true)
    .local(true)
    .node();
  client = node.client();
  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);
  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if (!ier.isExists()) {
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }
  list = boton.addScrollableList("playlist")
    .setPosition(400, 15)
    .setSize(200, 360)
    .setBarHeight(20)
    .setItemHeight(20)
    .setType(ScrollableList.LIST);
  loadFiles();
  fon1 = loadImage("fondo bajo.jpg");
  fon = loadImage("fondo.jpg");
}
void draw() {
  background(0);
  fill(255);
  rect(400, 0, 200, 360);
  image(fon, 0, 0, 400, 360);
  if (suena==true) {
    int m = datos.length()/60000;
    int s = (datos.length()/1000)-(m*60);
    textSize(12);
    text("Archivo: " + datos.fileName(), 5, 10);
    text("Titulo: " + datos.title(), 5, 25);
    text("Autor: " + datos.author(), 5, 40);
    text("Duracion: " + m + ":" + s, 5, 55);
    if (high==true || low==true) {
      stroke(255);
      for (int i = 0; i < output.bufferSize() - 1; i++)
      {
        float x1 = map(i, 0, output.bufferSize(), 0, 400);
        float x2 = map(i+1, 0, output.bufferSize(), 0, 400);
        line(x1, 2*(height-50)/4 - output.left.get(i)*50, x2, 2*(height-50)/4 - output.left.get(i+1)*50);
        line(x1, 3*(height-50)/4 - output.right.get(i)*50, x2, 3*(height-50)/4 - output.right.get(i+1)*50);
      }
    } else {
      noFill();
      fftLin.forward( sonido.mix );
      for (int i = 0; i < fftLin.specSize(); i++) {
        stroke(255);
        line(i, altura, i, altura - fftLin.getBand(i)*spectrumScale);
      }
    }
  }
}
void Play() {
  sonido.play();
}
void Pausa() {
  sonido.pause();
}
void Parar() {
  sonido.rewind();
  sonido.pause();
}
void Mas() {
  sonido.setGain(volumen+=3);
}
void Menos() {
  sonido.setGain(volumen-=3);
}
void HighPass() {
  if (high==false) {
    sonido.rewind();
    sonido.pause();
    son.patch( hpf ).patch( output );
    son.play();
    high=true;
  } else {
    son.rewind();
    son.pause();
    high=false;
  }
}
void LowPass() {
  if (low==false) {
    sonido.rewind();
    sonido.pause();
    son.patch( lpf ).patch( output );
    son.play();
    low=true;
  } else {
    son.rewind();
    son.pause();
    low=false;
  }
}
void Convoler() {
  if (con==false) {
    sonido.rewind();
    sonido.pause();
    son.rewind();
    son.pause();
    sonido.addEffect(lp);
    sonido.play();
    con=true;
  } else {
    sonido.rewind();
    sonido.pause();
    son.rewind();
    son.pause();
    con=false;
  }
}
void importFiles() {
  JFileChooser jfc = new JFileChooser();
  jfc.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  jfc.setMultiSelectionEnabled(true);
  jfc.showOpenDialog(null);
  for (File f : jfc.getSelectedFiles()) {
    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if (response.isExists()) {
      continue;
    }
    AudioPlayer sonido = minim.loadFile(f.getAbsolutePath());
    AudioMetaData datos = sonido.getMetaData();
    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", datos.author());
    doc.put("title", datos.title());
    doc.put("path", f.getAbsolutePath());
    try {
      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc)
        .execute()
        .actionGet();
      addItem(doc);
    } 
    catch(Exception e) {
      e.printStackTrace();
    }
  }
}

void playlist(int n) {
  if (suena==true) {
    sonido.rewind();
    sonido.pause();
    suena = false;
    son.rewind();
    son.pause();
    high=false;
    low=false;
  }
  sonido = minim.loadFile(direcciones[n], 1024);
  datos = sonido.getMetaData();
  suena=true;
  //sonido.play();
  son= new FilePlayer( minim.loadFileStream(direcciones[n]));
  output = minim.getLineOut();
  hpf = new HighPassSP(1000, output.sampleRate());
  lpf = new LowPassSP(100, output.sampleRate());
  float[] kernel = new float[] { 0, 0.005, 0.01, 0.018, 0.021, 0.03, 0.034, 0.037, 0.04, 0.042, 0.044, 0.046, 0.048, 0.049, 0.05, 
    0.049, 0.048, 0.046, 0.044, 0.042, 0.04, 0.037, 0.034, 0.03, 0.021, 0.018, 0.01, 0.005, 0 };
  lp = new Convolver(kernel, sonido.bufferSize());
  fftLin = new FFT( sonido.bufferSize(), sonido.sampleRate() );
}

void loadFiles() {
  try {
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();
    for (SearchHit hit : response.getHits().getHits()) {
      addItem(hit.getSource());
    }
  } 
  catch(Exception e) {
    e.printStackTrace();
  }
}

void addItem(Map<String, Object> doc) {
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
  archivo=doc.get("path")+"";
  direcciones[a]=archivo;
  a += 1;
}