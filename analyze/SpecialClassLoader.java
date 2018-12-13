package javacall;

import java.io.File;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;

class SpecialClassLoader extends URLClassLoader {
  public SpecialClassLoader(URL[] urls, ClassLoader parent) {
    super(urls, parent);
  }

  public void add(URL url) {
    this.addURL(url);
  }

  public void add(String path) throws MalformedURLException {
    this.add(new File(path).toURI().toURL());
  }
}
