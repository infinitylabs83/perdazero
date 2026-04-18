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

### 1. Configuração do Banco de Dados (Supabase)
1. Crie um novo projeto no [Supabase](https://supabase.com/).
2. Vá até a seção **SQL Editor** e execute o seguinte script para criar a estrutura e inserir dados de exemplo:

```sql
-- Limpeza (Atenção em produção!)
DROP TABLE IF EXISTS historico CASCADE;
DROP TABLE IF EXISTS equipe CASCADE;
DROP TABLE IF EXISTS produtos CASCADE;
DROP TABLE IF EXISTS lojas CASCADE;

-- Criação das Tabelas
CREATE TABLE lojas (id serial primary key, nome text not null);
CREATE TABLE equipe (id serial primary key, nome text not null, loja_id int references lojas(id), funcao text not null, codigo text, avatar text);
CREATE TABLE produtos (id serial primary key, nome text not null, icone text, custo numeric);
CREATE TABLE historico (id serial primary key, loja_id int references lojas(id), relator text, responsavel text, prod text, qtd numeric, uni text, motivo text, observacao text, hora text, img text, custo_total numeric, foto_url text, timestamp numeric, created_at timestamp with time zone default timezone('utc'::text, now()) not null);

-- Dados Iniciais (Admin Padrão)
INSERT INTO equipe (nome, loja_id, funcao, codigo, avatar) VALUES ('Admin', null, 'admin', '9999', '🛡️');
