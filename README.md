# 🍔 PerdaZero - Sistema de Controle de Desperdício (SaaS)

O **PerdaZero** é um aplicativo Web (PWA) focado na operação de restaurantes e fast-foods, projetado para registrar, monitorar e auditar perdas e desperdícios de insumos em tempo real. 

Nascido da necessidade de reduzir o atrito operacional em cozinhas movimentadas, o sistema utiliza uma arquitetura **Multi-Tenant** e opera em **Kiosk Mode**, permitindo que os colaboradores registrem perdas em poucos toques, sem a necessidade de digitar senhas constantemente.

---

## 🚀 Principais Funcionalidades

### 🧑‍🍳 Visão Operacional (Kiosk Mode / Cozinha)
* **Login sem Fricção:** Colaboradores tocam em seus próprios nomes/avatares para iniciar o fluxo.
* **Fluxo de Registro Rápido (5 Passos):**
  1. **Auditoria Visual:** Captura fotográfica obrigatória (ou opcional) da perda.
  2. **Identificação Inteligente:** Busca rápida de produtos com associação automática de emojis (ex: digitou "Carne", aparece 🥩).
  3. **Quantificação:** Teclado numérico otimizado para toque com suporte a unidades (Unid, Kg, Litros) e casas decimais.
  4. **Categorização:** Seleção rápida de motivos padrão (Queda, Validade Expirada, Erro de Preparo, etc).
  5. **Atribuição de Responsabilidade (Sigilosa):** Identificação de causa raiz ("Fui eu", "Não sei", "Outro colega") com opção de observações confidenciais.

### 👔 Visão Gerencial (Painel Administrativo)
* **Dashboard Global vs. Unidade:** Filtro inteligente que permite visualizar o prejuízo total da rede ou isolar os dados por loja específica.
* **Métricas em Tempo Real:** Filtros de período (Hoje, Semana, Mês) atualizando instantaneamente os indicadores de Volume Perdido e Prejuízo Financeiro (R$).
* **Rankings de Atenção:** Identificação clara do "Top 3 Produtos" mais perdidos e do "Top 3 Responsáveis" pelo desperdício.
* **Gráficos Visuais:** Gráficos interativos de rosca (por motivo) e de barras (por produto).
* **Gestão Completa (CRUD):** * Gestão de **Unidades** (Lojas da rede).
  * Gestão de **Produtos** (Nome, ícone e custo unitário).
  * Gestão de **Equipe** (Definição de PIN, Nível de Acesso e vinculação de Loja).
* **White-Label:** Personalização do nome da rede e upload de logomarca própria.

---

## 🛠️ Tecnologias Utilizadas

O projeto foi construído para ser leve, não necessitando de um processo complexo de *build*, rodando diretamente no navegador:

* **Frontend:** React 18 (via CDN)
* **Estilização:** Tailwind CSS (via CDN)
* **Gráficos:** Chart.js
* **Backend as a Service (BaaS):** Supabase (PostgreSQL + Auth + Storage)
* **Transpilação em Tempo Real:** Babel Standalone

---

## ⚙️ Como Configurar e Rodar o Projeto

Este projeto utiliza o **Supabase** como cérebro de dados. Para rodá-lo, você precisará de uma conta gratuita no Supabase.

> ⚠️ **O schema é multi-tenant** (várias empresas/redes no mesmo banco, isoladas por
> Row Level Security) e o fluxo de QR Code (sem login) passa inteiro por três funções
> `SECURITY DEFINER` no banco — nenhuma tabela é lida ou escrita diretamente pelo
> visitante anônimo. Isso é essencial: sem RLS correto, os dados de uma conta ficam
> visíveis para as outras.

### 1. Configuração do Banco de Dados (Supabase)
1. Crie um novo projeto no [Supabase](https://supabase.com/).
2. Vá até a seção **SQL Editor** e rode o conteúdo de [`supabase/schema.sql`](supabase/schema.sql) — ele cria tabelas, políticas de RLS, funções e o bucket de fotos, tudo do zero, num projeto vazio.
3. Em **Authentication → URL Configuration**, defina a Site URL como a URL onde o `index.html` vai ficar publicado, e adicione a mesma URL (com `/recuperar-senha.html`) em Redirect URLs.
4. Copie a **Project URL** e a chave **anon/public** (Settings → API) para as constantes `SUPABASE_URL`/`SUPABASE_KEY` no topo do `index.html`. Publicar a chave `anon` no código é esperado e seguro neste projeto — quem protege os dados é o RLS do passo 2, não o sigilo da chave.

---

## 🔒 Segurança

- **RLS liga tudo:** nenhuma tabela é acessível sem passar pela política `conta_id = minha_conta_id()`. Um dono só enxerga a própria conta.
- **Fluxo do QR Code (sem login)** não lê tabela nenhuma direto — usa três funções `SECURITY DEFINER`: `qr_contexto_loja`, `qr_verificar_pin` e `qr_registrar_perda`. O PIN do funcionário (`equipe.codigo`) nunca é devolvido ao navegador; `qr_verificar_pin` só responde `true`/`false`.
- **Fotos de evidência** ficam num bucket privado (`fotos_perdas`), com limite de 5 MB e só imagem. A URL de cada foto é assinada na hora, válida por 1h, e só o dono autenticado da conta consegue gerar essa URL.
- **Plano/trial** não pode ser alterado pelo próprio cliente: um gatilho no banco (`protege_colunas_plano`) reverte qualquer tentativa que não venha do `service_role`.
