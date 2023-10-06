# `flutter_libsparkmobile`
[SparkMobile](https://github.com/firoorg/sparkmobile) wrapped as a Flutter plugin for cross-platform mobile and desktop apps.  Intended to support Android, iOS, Linux, Mac, and Windows platforms.

## Development

### Generating bindings
Use [Gluecodium](https://github.com/heremaps/gluecodium) to generate a C ABI from C++ as in:
```sh
./generate -input /path/to/sparkmobile/src/spark.h -output /path/to/flutter_libsparkmobile
```