enum Emocao {
  feliz('Feliz', '😊'),
  triste('Triste', '😢'),
  ansioso('Ansioso', '😰'),
  produtivo('Produtivo', '🚀'),
  cansado('Cansado', '😴'),
  calmo('Calmo', '🌿');

  final String rotulo;
  final String emoji;

  const Emocao(this.rotulo, this.emoji);
}