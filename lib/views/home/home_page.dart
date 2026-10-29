import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/emocao.dart';
import '../../models/nota.dart';
import '../../repositories/nota_repository.dart';

const Color _lilasCalmo = Color(0xFFB8A9D9);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NotaRepository _repository = NotaRepository();
  late final TextEditingController _textoController;

  Nota? _notaEmEdicao;
  final Set<Emocao> _emocoesSelecionadas = {};
  DadosOfensiva? _ofensiva;

  @override
  void initState() {
    super.initState();
    _textoController = TextEditingController();
    _atualizarOfensiva();
  }

  Future<void> _atualizarOfensiva() async {
    final ofensiva = await _repository.calcularOfensiva();
    if (!mounted) return;
    setState(() {
      _ofensiva = ofensiva;
    });
  }

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  void _limparFormulario() {
    setState(() {
      _notaEmEdicao = null;
      _textoController.clear();
      _emocoesSelecionadas.clear();
    });
  }

  void _carregarNotaParaEdicao(Nota nota) {
    setState(() {
      _notaEmEdicao = nota;
      _textoController.text = nota.texto;
      _emocoesSelecionadas
        ..clear()
        ..addAll(nota.emocoes);
    });
  }

  Future<void> _salvarEAvancar() async {
    final novaNota = Nota(
      id: _notaEmEdicao?.id,
      texto: _textoController.text,
      pasta: _notaEmEdicao?.pasta ?? 'Geral',
      createdAt: _notaEmEdicao?.createdAt,
      emocoes: _emocoesSelecionadas,
    );

    if (!novaNota.isValida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escreva um texto ou selecione ao menos uma emoção.'),
        ),
      );
      return;
    }

    await _repository.salvar(novaNota);
    _limparFormulario();
    await _atualizarOfensiva();

    if (!mounted) return;

    await _irParaTelaDeCards();
  }

  Future<void> _irParaTelaDeCards() async {
    final notaParaEditar = await Navigator.of(context).push<Nota>(
      MaterialPageRoute(
        builder: (_) => NotasCardsPage(repository: _repository),
      ),
    );

    await _atualizarOfensiva();
    if (notaParaEditar != null && mounted) {
      _carregarNotaParaEdicao(notaParaEditar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emModoEdicao = _notaEmEdicao != null;
    final temConteudo =
        _textoController.text.trim().isNotEmpty || _emocoesSelecionadas.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(emModoEdicao ? 'Editar Nota #${_notaEmEdicao!.id}' : 'Meu Diário'),
        actions: [
          if (_ofensiva != null)
            _IndicadorOfensivaMinimalista(
              ofensiva: _ofensiva!,
              onTap: () => _mostrarModalOfensivaMinimalista(context, _ofensiva!),
            ),
          if (emModoEdicao || temConteudo)
            IconButton(
              icon: const Icon(Icons.restart_alt, color: _lilasCalmo),
              tooltip: 'Limpar',
              onPressed: _limparFormulario,
            ),
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined, color: _lilasCalmo),
            tooltip: 'Minhas Notas',
            onPressed: _irParaTelaDeCards,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8.0,
              runSpacing: 6.0,
              children: Emocao.values.map((emocao) {
                final selecionado = _emocoesSelecionadas.contains(emocao);
                return FilterChip(
                  label: Text(
                    '${emocao.emoji} ${emocao.rotulo}',
                    style: TextStyle(
                      fontWeight: selecionado ? FontWeight.w600 : FontWeight.normal,
                      color: selecionado ? _lilasCalmo : Colors.white70,
                    ),
                  ),
                  selected: selecionado,
                  onSelected: (bool ativo) {
                    setState(() {
                      if (ativo) {
                        _emocoesSelecionadas.add(emocao);
                      } else {
                        _emocoesSelecionadas.remove(emocao);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _textoController,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Color(0xFFEAE8F0), fontSize: 16),
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Escreva aqui seu desabafo ou pensamentos do dia...',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _salvarEAvancar,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(
                emModoEdicao ? 'Atualizar e Avançar' : 'Salvar e Avançar',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _lilasCalmo,
                side: BorderSide(color: _lilasCalmo.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _irParaTelaDeCards,
              icon: const Icon(Icons.style_outlined, size: 19),
              label: const Text('Ver Notas Salvas'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotasCardsPage extends StatefulWidget {
  final NotaRepository repository;

  const NotasCardsPage({super.key, required this.repository});

  @override
  State<NotasCardsPage> createState() => _NotasCardsPageState();
}

class _NotasCardsPageState extends State<NotasCardsPage> {
  List<Nota> _notas = [];
  bool _carregando = true;
  DadosOfensiva? _ofensiva;

  @override
  void initState() {
    super.initState();
    _carregarNotas();
  }

  Future<void> _carregarNotas() async {
    final notas = await widget.repository.listarTodas();
    final ofensiva = await widget.repository.calcularOfensiva();
    if (!mounted) return;
    setState(() {
      _notas = notas;
      _ofensiva = ofensiva;
      _carregando = false;
    });
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year;
    final hora = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano às $hora:$min';
  }

  Future<void> _excluirNota(Nota nota) async {
    if (nota.id == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir Nota #${nota.id}'),
        content: const Text('Deseja apagar esta nota? O ID ficará livre novamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: _lilasCalmo)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await widget.repository.excluir(nota.id!);
      await _carregarNotas();
    }
  }

  Future<void> _abrirDialogExportarMarkdown(Nota nota) async {
    final pastasExistentes = await widget.repository.listarPastas();
    if (!mounted) return;

    String pastaEscolhida = pastasExistentes.contains(nota.pasta)
        ? nota.pasta
        : pastasExistentes.first;
    final novaPastaController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1F29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Exportar Nota #${nota.id} em Markdown (.md)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _lilasCalmo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Escolha a pasta onde deseja separar o arquivo .md:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: pastasExistentes.map((p) {
                      final selecionada = p == pastaEscolhida &&
                          novaPastaController.text.trim().isEmpty;
                      return ChoiceChip(
                        label: Text(p),
                        selected: selecionada,
                        onSelected: (_) {
                          setModalState(() {
                            novaPastaController.clear();
                            pastaEscolhida = p;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: novaPastaController,
                    decoration: const InputDecoration(
                      hintText: 'Ou digite o nome de uma nova pasta...',
                      prefixIcon: Icon(
                        Icons.create_new_folder_outlined,
                        color: _lilasCalmo,
                        size: 20,
                      ),
                      isDense: true,
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _lilasCalmo,
                            side: BorderSide(
                              color: _lilasCalmo.withValues(alpha: 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () {
                            final destino =
                                novaPastaController.text.trim().isNotEmpty
                                    ? novaPastaController.text.trim()
                                    : pastaEscolhida;
                            final notaTemp = Nota(
                              id: nota.id,
                              texto: nota.texto,
                              pasta: destino,
                              createdAt: nota.createdAt,
                              emocoes: nota.emocoes,
                            );
                            Clipboard.setData(
                              ClipboardData(text: notaTemp.toMarkdown()),
                            );
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Markdown (.md) copiado!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copiar .md'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final destino =
                                novaPastaController.text.trim().isNotEmpty
                                    ? novaPastaController.text.trim()
                                    : pastaEscolhida;
                            final caminho = await widget.repository
                                .exportarNotaMarkdown(nota, destino);
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Salvo em "$destino/nota_${nota.id}.md"\n($caminho)',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Salvar .md'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _mostrarResumoSemanal() async {
    final resumo = await widget.repository.buscarResumoSemanal();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo Emocional (7 dias)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _lilasCalmo,
              ),
            ),
            const SizedBox(height: 16),
            if (resumo.isEmpty)
              const Text(
                'Nenhuma emoção registrada nesta semana.',
                style: TextStyle(color: Colors.white60),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: resumo.entries.map((entry) {
                  return Chip(
                    avatar: Text(entry.key.emoji),
                    label: Text('${entry.key.rotulo}: ${entry.value}x'),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Notas'),
        actions: [
          if (_ofensiva != null)
            _IndicadorOfensivaMinimalista(
              ofensiva: _ofensiva!,
              onTap: () => _mostrarModalOfensivaMinimalista(context, _ofensiva!),
            ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: _lilasCalmo),
            tooltip: 'Resumo Semanal',
            onPressed: _mostrarResumoSemanal,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _lilasCalmo))
          : _notas.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma nota salva ainda.',
                    style: TextStyle(fontSize: 16, color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: _notas.length,
                  itemBuilder: (context, index) {
                    final nota = _notas[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).pop(nota),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '#${nota.id}',
                                        style: const TextStyle(
                                          color: _lilasCalmo,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _formatarData(nota.createdAt),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.ios_share_outlined,
                                          color: _lilasCalmo,
                                          size: 18,
                                        ),
                                        tooltip: 'Exportar .md em pasta',
                                        onPressed: () =>
                                            _abrirDialogExportarMarkdown(nota),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.white38,
                                          size: 19,
                                        ),
                                        tooltip: 'Excluir nota',
                                        onPressed: () => _excluirNota(nota),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (nota.emocoes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: nota.emocoes.map((e) {
                                    return Text(
                                      '${e.emoji} ${e.rotulo}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _lilasCalmo,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              if (nota.texto.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  nota.texto,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFFEAE8F0),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova Nota',
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _IndicadorOfensivaMinimalista extends StatelessWidget {
  final DadosOfensiva ofensiva;
  final VoidCallback onTap;

  const _IndicadorOfensivaMinimalista({
    required this.ofensiva,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ativo = ofensiva.escreveuHoje;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 18,
              color: ativo ? _lilasCalmo : Colors.white38,
            ),
            const SizedBox(width: 3),
            Text(
              '${ofensiva.ofensivaAtual}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ativo ? _lilasCalmo : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _mostrarModalOfensivaMinimalista(
  BuildContext context,
  DadosOfensiva ofensiva,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1F1F29),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ofensiva: ${ofensiva.ofensivaAtual} ${ofensiva.ofensivaAtual == 1 ? "dia" : "dias"}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _lilasCalmo,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ofensiva.escreveuHoje
                ? 'Registro de hoje concluído.'
                : 'Escreva uma nota hoje para manter sua sequência.',
            style: const TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ofensiva.ultimos7Dias.map((d) {
              return Column(
                children: [
                  Text(
                    d.rotulo,
                    style: TextStyle(
                      fontSize: 11,
                      color: d.ehHoje ? _lilasCalmo : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.concluido
                          ? _lilasCalmo.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.05),
                      border: d.ehHoje
                          ? Border.all(color: _lilasCalmo, width: 1.2)
                          : null,
                    ),
                    child: d.concluido
                        ? const Icon(Icons.check, size: 14, color: _lilasCalmo)
                        : null,
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Recorde: ${ofensiva.melhorOfensiva} dias  •  Total: ${ofensiva.totalDiasRegistrados} dias',
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    ),
  );
}
