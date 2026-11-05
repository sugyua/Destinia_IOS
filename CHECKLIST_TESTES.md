# Checklist de validação no iPhone 15 Pro Max / iOS 27

Este checklist não indica testes concluídos. Somente marque após validar no aparelho.

## Primeira inicialização

- [ ] Sideloadly assina o IPA com a conta gratuita e instala no iPhone.
- [ ] Aplicativo abre em landscape e não fecha sozinho.
- [ ] Servidor interno na porta 19406 inicia.
- [ ] Web Worker carrega o Unicorn ARM/WASM e os dados originais sem erro.
- [ ] Logotipos e menu do Destinia aparecem sem distorções.
- [ ] Testar FPS real, inclusive exploração e combate; registrar aquecimento e consumo de bateria.

## Controles e interface

- [ ] Toques em menu, movimento, ataque e habilidades funcionam.
- [ ] Safe areas, Dynamic Island e cantos não escondem botões.
- [ ] Tela não muda para retrato.
- [ ] Zoom da UI não interfere com coordenadas de toque.
- [ ] Menu de inventário, personagem, Códex, dificuldades e loja abre/fecha.

## Dados e continuidade (usar save de teste, não personagem principal)

- [ ] Criar personagem e salvar usando a ação original do jogo.
- [ ] Fechar app por completo e reabrir; personagem volta com progresso intacto.
- [ ] Salvar novamente, testar morte/retorno, reiniciar.
- [ ] Excluir um personagem de teste e confirmar que não reaparece ao reiniciar.
- [ ] Configurações de jogo e sidecars (inventário, QoL) sobrevivem ao restart.
- [ ] Renovações por Sideloadly preservam saves com mesmo bundle ID.
- [ ] Testar cópia de segurança antes de desinstalar o aplicativo.

## Plataforma

- [ ] Testar sem Wi-Fi e sem dados móveis; execução deve permanecer offline.
- [ ] Verificar se a app volta da tela bloqueada ou perde apenas estado em memória.
- [ ] Testar áudio: **não implementado na primeira candidata**.
- [ ] Testar controle Bluetooth (opcional; não validado).

## Critérios mínimos de candidata jogável

- Carregar o jogo, criar personagem, jogar por 10 minutos e carregar save após reinicialização completa.
- Sem corrupção de dados; sem travamentos repetitivos.
- Taxa de quadros suficiente no dispositivo real e bateria/temperatura aceitáveis.
