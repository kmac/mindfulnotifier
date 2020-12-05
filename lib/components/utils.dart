String timeNumToString(int source) {
  if (source < 10) {
    return "0$source";
  }
  return source.toString();
}
