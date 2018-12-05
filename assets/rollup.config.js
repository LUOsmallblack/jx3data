import alias from 'rollup-plugin-alias';
import resolve from 'rollup-plugin-node-resolve';
import commonjs from 'rollup-plugin-commonjs';
import replace from 'rollup-plugin-replace';
import bucklescript from 'rollup-plugin-bucklescript';
import copy from 'rollup-plugin-copy-glob';

export default {
  input: 'src/Demo.bs.js',
  output: {
    name: 'viewer',
    file: 'static/bundle.js',
    format: 'iife',
    sourcemap: true,
    globals: {
      "react": "React",
      "react-dom": "ReactDOM",
    },
  },
  plugins: [
    copy([
      { files: 'node_modules/react/umd/react.development.js', dest: "static" },
      { files: 'node_modules/react-dom/umd/react-dom.development.js', dest: "static" },
      { files: 'src/*.html', dest: "static" },
    ], {verbose: true}),
    bucklescript(),
    alias({
      resolve: ['.js', '.re']
    }),
    replace({
      'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'development')
    }),
    resolve(),
    commonjs(),
  ],
  external: ['react', 'react-dom'],
};
