# Requisitos da cliente (fonte original)

Conversa por WhatsApp em 17/10/2026, transcrita sem alterações (telefone da cliente omitido).
A especificação interpretada está na skill `app-igreja`; dúvidas em aberto ficam na seção "Pendências de confirmação" abaixo.

---

**[18:16] Caetano:** Tirei umas horas do dia hoje para estudar a InChurch e pensar no app. Antes de montar a proposta, queria entender melhor o que você precisa:

1. A ideia é continuar usando o site da InChurch como sistema principal da igreja com o app conversando com ela? Ou pensa em, no futuro, deixar de usar a InChurch?
2. O que te fez querer um app próprio? Tem algo no app da InChurch que não te atende? E deseja adicionar a mais nesse APP?
3. Quais funções são essenciais no começo? (ex.: agenda, eventos, células, avisos, vídeos/ao vivo, pedidos de oração, dízimo, notificações)
4. O app seria só para a sua igreja ou também para filiais/congregações? Quantos membros, mais ou menos?
5. Tem um prazo ou orçamento em mente?

**[18:23] Cliente:** A intenção é deixar a inchurch, no momento não iremos acrescentar muito. O essencial é agenda, membros, eventos, lideranças(Aba mensagens) notificações, pedidos de oração, mídias (galeria de fotos e vídeos). Espaço para estudo diário onde iremos postar um pouquinho por dia.
Seria somente para 1 igreja sem filiais são em média 150 a 250 membros
O prazo seria o mais breve possível dentro das limitações do desenvolvimento claro.
E não tenho um orçamento em mente não
Parte de células e financeiro somente para registrar contas a pagar e status pago ou não

**[18:36] Caetano:** Entendido.
Só mais me confirme, são aplicativos mobile, certo? Serão instalados pelas lojas dos celulares e tablets, e não terão acesso pelo computador (por exemplo no google chrome).
Ou a ideia é ter aplicativo de celular e também site próprio?

**[18:37] Cliente:** Somente para celulares e tablets.

---

## Requisitos extraídos

| Pedido da cliente | Onde está na especificação |
|---|---|
| Deixar a InChurch | UC-40 (importação) e app como sistema principal |
| Agenda | UC-11, UC-15 |
| Membros | UC-06 a UC-10 |
| Eventos | UC-12 a UC-14, UC-16 |
| "Lideranças (aba mensagens)" | UC-17, UC-18 (interpretado como comunicados) — **confirmar** |
| Notificações | UC-19 a UC-21 |
| Pedidos de oração | UC-22 a UC-26 |
| Mídias: galeria de fotos e vídeos | UC-27 a UC-30 |
| Estudo diário ("um pouquinho por dia") | UC-31 a UC-34 |
| Financeiro: contas a pagar e status pago/não pago | UC-35 a UC-38 |
| Células | fora do escopo (premissa 4) — **confirmar** |
| 1 igreja, sem filiais, 150–250 membros | seção 1 |
| Só celular e tablet, sem site | seção 1 |
| Prazo: o mais breve possível | ordem de implementação (seção 11) |
| Sem dízimo / pagamentos | seção 1 (não citado pela cliente) |

## Decisões (19/10/2026)

1. **Células:** fora do escopo. A frase só detalhava o financeiro (contas a pagar + status pago/não pago).
2. **"Lideranças (aba mensagens)":** somente mensagens dos líderes para os membros (comunicados, UC-17/UC-18).
3. **Membros:** o app vira a ficha oficial. Campos adicionados: endereço, gênero, estado civil, data de batismo e data de membresia.
4. **Fluxo de caixa (entradas e saídas):** sugestão do desenvolvedor, além do que a cliente pediu. Definido como UC-41 a UC-43 (caixa único; conta paga gera saída automática; doador = membro ou nome livre). Entra na etapa 5, **depois de validar com a cliente**.
