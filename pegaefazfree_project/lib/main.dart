import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

const String supabaseProjectUrl = 'https://ctrsnhbfkbbhwulsnxrh.supabase.co';

// Chave usada para inicializar o app Flutter/Supabase.
// Essa chave nova começa com sb_publishable_ e deve continuar aqui.
const String supabaseAnonKey = 'sb_publishable_tiTRVWmZNo2wk2h76twYLQ_YyEscQ1S';

// A autenticação das Edge Functions deve usar a sessão real do usuário logado.
// NÃO coloque service_role no app. A service_role fica somente dentro das Edge Functions.


@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: supabaseProjectUrl,
    anonKey: supabaseAnonKey,
  );

final user = Supabase.instance.client.auth.currentUser;

if (user != null) {
  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('is_blocked')
        .eq('id', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 3));

    if (response != null && response['is_blocked'] == true) {
      runApp(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                '🚫 Usuário bloqueado',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
        ),
      );
      return;
    }
  } catch (_) {
    // Se a checagem falhar, deixa o app abrir normalmente.
  }
}
  runApp(const PegaeFazFreeApp());
}

final supabase = Supabase.instance.client;


bool _pushTokenRefreshListenerStarted = false;

Future<void> saveDeviceTokenForPush({String? token}) async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    final resolvedToken = token ?? await FirebaseMessaging.instance.getToken();
    if (resolvedToken == null || resolvedToken.trim().isEmpty) return;

    await supabase.from('device_tokens').upsert({
      'user_id': user.id,
      'token': resolvedToken,
      'platform': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other',
      'device_info': Platform.operatingSystem,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  } catch (_) {
    // Push não pode impedir o app de abrir.
  }
}

Future<void> setupPushNotificationsForCurrentUser() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    await saveDeviceTokenForPush();

    if (!_pushTokenRefreshListenerStarted) {
      _pushTokenRefreshListenerStarted = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        saveDeviceTokenForPush(token: token);
      });
    }
  } catch (_) {
    // Push é complementar. Se falhar, o app continua funcionando.
  }
}

const String roleClient = 'client';
const String roleWorker = 'worker';
const String roleClientCompany = 'client_company';
const String roleAdmin = 'admin';
const String privilegedAdminEmail = 'pegaefazfree@gmail.com';

const String resetPasswordRedirectUrl = 'pegaefazfree://reset-password';
const String authCallbackRedirectUrl = 'pegaefazfree://auth-callback';
const String emailConfirmationRedirectUrl = 'https://www.pegaefazfree.com.br/confirmacao.html';
const bool womanSpaceTemporarilyDisabled = true;

bool isPrivilegedAdminEmail(String? email) =>
    (email ?? '').trim().toLowerCase() == privilegedAdminEmail;

bool boolFromDynamic(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'sim' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'nao' || text == 'não' || text == 'no') return false;
  return defaultValue;
}


String onlyDigits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

String normalizedUf(String value) => value.trim().toUpperCase();

const String supportedLaunchState = 'SC';

const List<String> brazilStatesLaunchOptions = [
  'SC - Santa Catarina',
  'PR - Paraná (em breve)',
  'RS - Rio Grande do Sul (em breve)',
  'SP - São Paulo (em breve)',
  'RJ - Rio de Janeiro (em breve)',
  'MG - Minas Gerais (em breve)',
  'BA - Bahia (em breve)',
  'ES - Espírito Santo (em breve)',
  'GO - Goiás (em breve)',
  'DF - Distrito Federal (em breve)',
  'MS - Mato Grosso do Sul (em breve)',
  'MT - Mato Grosso (em breve)',
  'AC - Acre (em breve)',
  'AL - Alagoas (em breve)',
  'AP - Amapá (em breve)',
  'AM - Amazonas (em breve)',
  'CE - Ceará (em breve)',
  'MA - Maranhão (em breve)',
  'PA - Pará (em breve)',
  'PB - Paraíba (em breve)',
  'PE - Pernambuco (em breve)',
  'PI - Piauí (em breve)',
  'RN - Rio Grande do Norte (em breve)',
  'RO - Rondônia (em breve)',
  'RR - Roraima (em breve)',
  'SE - Sergipe (em breve)',
  'TO - Tocantins (em breve)',
];

const List<String> scPriorityCities = [
  'Criciúma',
  'Içara',
  'Forquilhinha',
  'Cocal do Sul',
  'Morro da Fumaça',
  'Nova Veneza',
  'Siderópolis',
  'Treviso',
  'Urussanga',
  'Orleans',
  'Lauro Müller',
  'Araranguá',
  'Balneário Rincão',
  'Tubarão',
];

const List<String> scCities = [
  ...scPriorityCities,
  'Abdon Batista',
  'Abelardo Luz',
  'Agrolândia',
  'Agronômica',
  'Água Doce',
  'Águas de Chapecó',
  'Águas Frias',
  'Águas Mornas',
  'Alfredo Wagner',
  'Alto Bela Vista',
  'Anchieta',
  'Angelina',
  'Anita Garibaldi',
  'Anitápolis',
  'Antônio Carlos',
  'Apiúna',
  'Arabutã',
  'Araquari',
  'Armazém',
  'Arroio Trinta',
  'Ascurra',
  'Atalanta',
  'Aurora',
  'Balneário Arroio do Silva',
  'Balneário Barra do Sul',
  'Balneário Camboriú',
  'Balneário Gaivota',
  'Balneário Piçarras',
  'Balneário Rincão',
  'Bandeirante',
  'Barra Bonita',
  'Barra Velha',
  'Bela Vista do Toldo',
  'Belmonte',
  'Benedito Novo',
  'Biguaçu',
  'Blumenau',
  'Bocaina do Sul',
  'Bombinhas',
  'Bom Jardim da Serra',
  'Bom Jesus',
  'Bom Jesus do Oeste',
  'Bom Retiro',
  'Botuverá',
  'Braço do Norte',
  'Braço do Trombudo',
  'Brunópolis',
  'Brusque',
  'Caçador',
  'Caibi',
  'Calmon',
  'Camboriú',
  'Campo Alegre',
  'Campo Belo do Sul',
  'Campo Erê',
  'Campos Novos',
  'Canelinha',
  'Canoinhas',
  'Capão Alto',
  'Capinzal',
  'Capivari de Baixo',
  'Catanduvas',
  'Caxambu do Sul',
  'Celso Ramos',
  'Cerro Negro',
  'Chapadão do Lageado',
  'Chapecó',
  'Cocal do Sul',
  'Concórdia',
  'Cordilheira Alta',
  'Coronel Freitas',
  'Coronel Martins',
  'Correia Pinto',
  'Corupá',
  'Criciúma',
  'Cunha Porã',
  'Cunhataí',
  'Curitibanos',
  'Descanso',
  'Dionísio Cerqueira',
  'Dona Emma',
  'Doutor Pedrinho',
  'Entre Rios',
  'Ermo',
  'Erval Velho',
  'Faxinal dos Guedes',
  'Flor do Sertão',
  'Florianópolis',
  'Formosa do Sul',
  'Forquilhinha',
  'Fraiburgo',
  'Frei Rogério',
  'Galvão',
  'Garopaba',
  'Garuva',
  'Gaspar',
  'Governador Celso Ramos',
  'Grão Pará',
  'Gravatal',
  'Guabiruba',
  'Guaraciaba',
  'Guaramirim',
  'Guarujá do Sul',
  'Guatambú',
  'Herval d’Oeste',
  'Ibiam',
  'Ibicaré',
  'Ibirama',
  'Içara',
  'Ilhota',
  'Imaruí',
  'Imbituba',
  'Imbuia',
  'Indaial',
  'Iomerê',
  'Ipira',
  'Iporã do Oeste',
  'Ipuaçu',
  'Ipumirim',
  'Iraceminha',
  'Irani',
  'Irati',
  'Irineópolis',
  'Itá',
  'Itaiópolis',
  'Itajaí',
  'Itapema',
  'Itapiranga',
  'Itapoá',
  'Ituporanga',
  'Jaborá',
  'Jacinto Machado',
  'Jaguaruna',
  'Jaraguá do Sul',
  'Jardinópolis',
  'Joaçaba',
  'Joinville',
  'José Boiteux',
  'Jupiá',
  'Lacerdópolis',
  'Lages',
  'Laguna',
  'Lajeado Grande',
  'Laurentino',
  'Lauro Müller',
  'Lebon Régis',
  'Leoberto Leal',
  'Lindóia do Sul',
  'Lontras',
  'Luiz Alves',
  'Luzerna',
  'Macieira',
  'Mafra',
  'Major Gercino',
  'Major Vieira',
  'Maracajá',
  'Maravilha',
  'Marema',
  'Massaranduba',
  'Matos Costa',
  'Meleiro',
  'Mirim Doce',
  'Modelo',
  'Mondaí',
  'Monte Carlo',
  'Monte Castelo',
  'Morro da Fumaça',
  'Morro Grande',
  'Navegantes',
  'Nova Erechim',
  'Nova Itaberaba',
  'Nova Trento',
  'Nova Veneza',
  'Novo Horizonte',
  'Orleans',
  'Otacílio Costa',
  'Ouro',
  'Ouro Verde',
  'Paial',
  'Painel',
  'Palhoça',
  'Palma Sola',
  'Palmeira',
  'Palmitos',
  'Papanduva',
  'Paraíso',
  'Passo de Torres',
  'Passos Maia',
  'Paulo Lopes',
  'Pedras Grandes',
  'Penha',
  'Peritiba',
  'Pescaria Brava',
  'Petrolândia',
  'Pinhalzinho',
  'Pinheiro Preto',
  'Piratuba',
  'Planalto Alegre',
  'Pomerode',
  'Ponte Alta',
  'Ponte Alta do Norte',
  'Ponte Serrada',
  'Porto Belo',
  'Porto União',
  'Pouso Redondo',
  'Praia Grande',
  'Presidente Castello Branco',
  'Presidente Getúlio',
  'Presidente Nereu',
  'Princesa',
  'Quilombo',
  'Rancho Queimado',
  'Rio das Antas',
  'Rio do Campo',
  'Rio do Oeste',
  'Rio do Sul',
  'Rio dos Cedros',
  'Rio Fortuna',
  'Rio Negrinho',
  'Rio Rufino',
  'Riqueza',
  'Rodeio',
  'Romelândia',
  'Salete',
  'Saltinho',
  'Salto Veloso',
  'Sangão',
  'Santa Cecília',
  'Santa Helena',
  'Santa Rosa de Lima',
  'Santa Rosa do Sul',
  'Santa Terezinha',
  'Santa Terezinha do Progresso',
  'Santiago do Sul',
  'Santo Amaro da Imperatriz',
  'São Bento do Sul',
  'São Bernardino',
  'São Bonifácio',
  'São Carlos',
  'São Cristóvão do Sul',
  'São Domingos',
  'São Francisco do Sul',
  'São João Batista',
  'São João do Itaperiú',
  'São João do Oeste',
  'São João do Sul',
  'São Joaquim',
  'São José',
  'São José do Cedro',
  'São José do Cerrito',
  'São Lourenço do Oeste',
  'São Ludgero',
  'São Martinho',
  'São Miguel da Boa Vista',
  'São Miguel do Oeste',
  'Saudades',
  'Schroeder',
  'Seara',
  'Serra Alta',
  'Siderópolis',
  'Sombrio',
  'Sul Brasil',
  'Taió',
  'Tangará',
  'Tigrinhos',
  'Tijucas',
  'Timbé do Sul',
  'Timbó',
  'Timbó Grande',
  'Três Barras',
  'Treviso',
  'Treze de Maio',
  'Treze Tílias',
  'Trombudo Central',
  'Tubarão',
  'Tunápolis',
  'Turvo',
  'União do Oeste',
  'Urubici',
  'Urupema',
  'Urussanga',
  'Vargeão',
  'Vargem',
  'Vargem Bonita',
  'Vidal Ramos',
  'Videira',
  'Vitor Meireles',
  'Witmarsum',
  'Xanxerê',
  'Xavantina',
  'Xaxim',
  'Zortéa',
];

List<String> uniqueScCities() {
  final seen = <String>{};
  final list = <String>[];
  for (final city in scCities) {
    final key = city.trim().toLowerCase();
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    list.add(city);
  }
  return list;
}

bool isScCity(String value) {
  final normalized = value.trim().toLowerCase();
  return uniqueScCities().any((city) => city.toLowerCase() == normalized);
}

String normalizeLaunchCity(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  for (final city in uniqueScCities()) {
    if (city.toLowerCase() == trimmed.toLowerCase()) return city;
  }
  return trimmed;
}



Future<Map<String, String>?> fetchAddressFromCep(String cep) async {
  final digits = onlyDigits(cep);
  if (digits.length != 8) return null;

  try {
    final uri = Uri.parse('https://viacep.com.br/ws/$digits/json/');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['erro'] == true) return null;

    return {
      'cep': digits,
      'address': (decoded['logradouro'] ?? '').toString(),
      'neighborhood': (decoded['bairro'] ?? '').toString(),
      'city': (decoded['localidade'] ?? '').toString(),
      'state': (decoded['uf'] ?? '').toString().toUpperCase(),
    };
  } catch (_) {
    return null;
  }
}

Future<bool> isCurrentEmailConfirmed() async {
  final user = supabase.auth.currentUser;
  if (user == null) return false;
  return user.emailConfirmedAt != null;
}


String roleLabelPt(String role) {
  switch (role.trim().toLowerCase()) {
    case roleWorker:
      return 'Prestador';
    case roleClientCompany:
      return 'Cliente empresa';
    case roleAdmin:
      return 'Administrador';
    case roleClient:
    default:
      return 'Cliente';
  }
}

String displayProfileNameFromMap(
  Map<String, dynamic>? profile, {
  String fallback = 'Usuário',
}) {
  if (profile == null) return fallback;
  final email = profile['email']?.toString();
  final role = (profile['role'] ?? '').toString();
  if (role == roleAdmin || isPrivilegedAdminEmail(email)) return 'Equipe PegaeFazFree';
  if (role == roleClientCompany) {
    final tradeName = (profile['company_trade_name'] ?? '').toString().trim();
    final legalName = (profile['company_legal_name'] ?? '').toString().trim();
    final responsible = (profile['company_responsible'] ?? '').toString().trim();
    if (tradeName.isNotEmpty) return tradeName;
    if (legalName.isNotEmpty) return legalName;
    if (responsible.isNotEmpty) return responsible;
  }
  final name = (profile['name'] ?? '').toString().trim();
  if (name.isNotEmpty && name.toLowerCase() != 'usuário' && name.toLowerCase() != 'usuario') return name;
  if (email != null && email.trim().isNotEmpty) {
    final emailName = email.split('@').first.trim();
    if (emailName.isNotEmpty) return emailName;
  }
  return fallback;
}

String displayProfileInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'P';
  return trimmed.substring(0, 1).toUpperCase();
}

bool isDeletedProfileMap(Map<String, dynamic>? profile) {
  if (profile == null) return false;

  if (boolFromDynamic(profile['is_deleted'])) return true;
  if (profile['deleted_at'] != null &&
      profile['deleted_at'].toString().trim().isNotEmpty) {
    return true;
  }

  final name = (profile['name'] ?? '').toString().trim().toLowerCase();
  return name == 'usuário excluído' ||
      name == 'usuario excluido' ||
      name == 'conta excluída' ||
      name == 'conta excluida';
}

bool isClientRole(String role) {
  final normalized = role.trim().toLowerCase();
  return normalized == roleClient || normalized == roleClientCompany;
}

Future<void> bloquearUsuario(String userId) async {
  final supabase = Supabase.instance.client;

  await supabase
      .from('profiles')
      .update({'is_blocked': true})
      .eq('id', userId);
}

Future<bool> usuarioBloqueado() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return false;

  try {
    final data = await supabase
        .from('profiles')
        .select('is_blocked')
        .eq('id', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 3));

    return data != null && data['is_blocked'] == true;
  } catch (_) {
    return false;
  }
}

Future<void> moderateMessageWithEdgeFunction(String texto) async {
  final supabase = Supabase.instance.client;

  final response = await supabase.functions.invoke(
    'ai_moderation',
    body: {
      "text": texto,
      "sourceType": "chat",
      "userId": supabase.auth.currentUser?.id,
    },
  );

  final data = response.data;

  if (data != null && data['blocked'] == true) {
    throw Exception('Mensagem bloqueada pela IA');
  }
}

const List<String> appCategories = [
  'Todos',
  'Reformas e Reparos',
  'Limpeza',
  'Serviços Domésticos',
  'Assistência Técnica',
  'Design e Tecnologia',
  'Eventos e Hospitalidade',
  'Moda e Beleza',
  'Saúde e Bem-estar',
  'Aulas e Reforço Escolar',
  'Consultoria e Escritório',
  'Automóveis e Veículos',
  'Segurança e Monitoramento',
  'Alimentos e Gastronomia',
  'Jardinagem e Áreas Externas',
  'Mudanças e Fretes',
  'Pets e Veterinária',
  'Costura e Lavanderia',
  'Piscinas e Lazer',
  'Serviços para Empresas',
  'Outros',
];

const List<String> specialtySuggestions = [
  'Diarista', 'Pedreiro', 'Eletricista', 'Encanador', 'Pintor',
  'Motoboy', 'Entregador', 'Motorista particular', 'Jardineiro', 'Montador de móveis',
  'Faxineira', 'Camareira', 'Governanta', 'Babá', 'Cuidador de idosos',
  'Passadeira', 'Cozinheira', 'Lavadeira', 'Personal organizer', 'Servente',
  'Marido de aluguel', 'Soldador', 'Serralheiro', 'Marceneiro', 'Vidraceiro',
  'Podóloga', 'Esteticista', 'Lash designer', 'Maquiadora', 'Manicure e pedicure',
  'Estilista', 'Recepcionista', 'Fotógrafo', 'DJ', 'Garçom',
  'Bartender', 'Promotor de eventos', 'Panfletagem', 'Eventos corporativos', 'Segurança para eventos',
  'Professor de Português', 'Professor de História', 'Professor de Espanhol', 'Professor de Ciências', 'Professor de Matemática',
  'Professor de Física', 'Professor de Arte', 'Professor de Música', 'Professor de Biologia', 'Professor de Geografia',
  'Aulas de direção', 'Educação financeira', 'Culinária e gastronomia', 'Educação especial e inclusiva', 'Preparatório para concursos',
  'Preparatório para ENEM', 'Guarda', 'Vigia', 'Vigilante', 'Porteiro',
  'Zelador', 'Monitoramento residencial', 'Segurança privada', 'Churrasqueiro', 'Açougueiro',
  'Confeiteiro', 'Padeiro', 'Sommelier de vinhos', 'Sommelier de alimentos', 'Promotor',
  'Promotor de vendas', 'Representante comercial', 'Borracheiro', 'Eletricista automotivo', 'Eletricista de caminhão',
  'Chapeador', 'Mecânico', 'Auto elétrica', 'Funilaria', 'Guincho',
  'Higienização automotiva', 'Estética automotiva', 'Dedetizador', 'Veterinário', 'Médico geral',
  'Pediatra', 'Enfermeiro', 'Cardiologista', 'Técnico de enfermagem', 'Fisioterapeuta',
  'Psicólogo', 'Dentista', 'Nutricionista', 'Farmacêutico', 'Advogado',
  'Contador', 'Arquiteto', 'Engenheiro', 'Social media', 'Desenvolvedor de aplicativos',
  'Designer gráfico', 'Suporte técnico', 'Ar-condicionado', 'Chaveiro',
];

const Map<String, List<String>> workerSpecialtyExtrasByCategory = {
  'Reformas e Reparos': [
    'Profissional de reformas',
    'Instalador de drywall',
  ],
  'Limpeza': [
    'Faxineira',
    'Profissional de limpeza',
    'Lavador de estofados',
  ],
  'Serviços Domésticos': [
    'Cuidador domiciliar',
  ],
  'Assistência Técnica': [
    'Técnico de celular',
    'Técnico de informática',
    'Técnico de notebook',
    'Técnico de TV',
    'Técnico de eletrodomésticos',
    'Técnico de refrigeração',
    'Técnico de ar-condicionado',
    'Técnico de redes e internet',
  ],
  'Design e Tecnologia': [
    'Editor de vídeo',
    'Web designer',
    'Desenvolvedor web',
    'Programador',
    'Gestor de tráfego',
  ],
  'Eventos e Hospitalidade': [
    'Decorador de eventos',
    'Assessor de eventos',
    'Técnico de som e iluminação',
  ],
  'Moda e Beleza': [
    'Designer de unhas',
  ],
  'Saúde e Bem-estar': [
    'Dentista',
    'Farmacêutico',
  ],
  'Aulas e Reforço Escolar': [
    'Professor particular',
  ],
  'Consultoria e Escritório': [
    'Assistente administrativo',
  ],
  'Automóveis e Veículos': [
    'Mecânico de caminhão',
  ],
  'Segurança e Monitoramento': [
    'Técnico de câmeras e alarmes',
  ],
  'Alimentos e Gastronomia': [
    'Cozinheiro',
  ],
  'Jardinagem e Áreas Externas': [
    'Roçador',
  ],
  'Mudanças e Fretes': [
    'Freteiro',
  ],
  'Pets e Veterinária': [
    'Cuidador de pets',
  ],
  'Costura e Lavanderia': [
    'Passadeira',
  ],
  'Piscinas e Lazer': [
    'Piscineiro',
  ],
  'Serviços para Empresas': [
    'Auxiliar operacional',
  ],
  'Outros': [
    'Dedetizador',
  ],
};


const Map<String, List<String>> categorySubservices = {
  'Reformas e Reparos': [
    'Pedreiro', 'Servente', 'Mestre de obras', 'Marido de aluguel', 'Montador de móveis',
    'Gesseiro', 'Drywall', 'Azulejista', 'Telhadista', 'Calheiro', 'Soldador', 'Serralheiro',
    'Marceneiro', 'Vidraceiro', 'Pintor', 'Eletricista', 'Encanador', 'Chaveiro'
  ],
  'Limpeza': [
    'Diarista', 'Faxina completa', 'Limpeza comercial', 'Limpeza pós-obra', 'Limpeza pesada',
    'Limpeza de vidros', 'Higienização', 'Lavagem de estofados', 'Camareira', 'Governanta'
  ],
  'Serviços Domésticos': [
    'Babá', 'Cuidador de idosos', 'Cuidador de crianças', 'Passadeira', 'Cozinheira',
    'Lavadeira', 'Organização da casa', 'Personal organizer', 'Caseiro', 'Zelador'
  ],
  'Assistência Técnica': [
    'Conserto de celular', 'Conserto de computador', 'Conserto de notebook', 'Conserto de TV',
    'Conserto de eletrodomésticos', 'Conserto de geladeira', 'Ar-condicionado', 'Instalação de ar-condicionado', 'Manutenção de ar-condicionado', 'Higienização de ar-condicionado', 'Suporte técnico', 'Redes e internet'
  ],
  'Design e Tecnologia': [
    'Designer gráfico', 'Criação de logo', 'Social media', 'Marketing digital', 'Edição de vídeos',
    'Criação de sites', 'Desenvolvimento de aplicativos', 'Programação', 'Gestão de tráfego'
  ],
  'Eventos e Hospitalidade': [
    'Garçom', 'Bartender', 'Recepcionista', 'DJ', 'Som e iluminação', 'Fotógrafo', 'Filmagem',
    'Decoração', 'Assessoria de eventos', 'Churrasqueiro', 'Promotor de eventos', 'Panfletagem', 'Eventos corporativos'
  ],
  'Moda e Beleza': [
    'Cabeleireiro', 'Barbeiro', 'Maquiadora', 'Manicure e pedicure', 'Designer de sobrancelhas',
    'Lash designer', 'Esteticista', 'Podóloga', 'Depilação', 'Estilista'
  ],
  'Saúde e Bem-estar': [
    'Médico geral', 'Pediatra', 'Cardiologista', 'Enfermeiro', 'Técnico de enfermagem',
    'Fisioterapeuta', 'Nutricionista', 'Psicólogo', 'Massoterapeuta', 'Veterinário'
  ],
  'Aulas e Reforço Escolar': [
    'Professor de Português', 'Professor de História', 'Professor de Espanhol', 'Professor de Ciências',
    'Professor de Matemática', 'Professor de Física', 'Professor de Arte', 'Professor de Música',
    'Professor de Biologia', 'Professor de Geografia', 'Aulas de direção', 'Educação financeira',
    'Culinária e gastronomia', 'Educação especial e inclusiva', 'Preparatório para concursos', 'Preparatório para ENEM'
  ],
  'Consultoria e Escritório': [
    'Advogado', 'Contador', 'Consultor financeiro', 'Consultor empresarial', 'Representante comercial',
    'Despachante', 'Tradutor', 'Corretor'
  ],
  'Automóveis e Veículos': [
    'Mecânico', 'Borracheiro', 'Eletricista automotivo', 'Eletricista de caminhão', 'Chapeador',
    'Funilaria', 'Guincho', 'Higienização automotiva', 'Estética automotiva', 'Auto elétrica', 'Motorista particular'
  ],
  'Segurança e Monitoramento': [
    'Guarda', 'Vigia', 'Vigilante', 'Porteiro', 'Zelador', 'Monitoramento residencial', 'Segurança privada',
    'Instalação de câmeras', 'Instalação de alarme', 'Cerca elétrica', 'Portão eletrônico', 'Segurança para eventos'
  ],
  'Alimentos e Gastronomia': [
    'Açougueiro', 'Churrasqueiro', 'Confeiteiro', 'Padeiro', 'Sommelier de vinhos',
    'Sommelier de alimentos', 'Cozinheira', 'Buffet'
  ],
  'Jardinagem e Áreas Externas': [
    'Jardineiro', 'Paisagista', 'Poda', 'Roçada', 'Limpeza de terreno', 'Piscineiro'
  ],
  'Mudanças e Fretes': [
    'Mudança residencial', 'Mudança comercial', 'Frete pequeno', 'Carreto', 'Motoboy', 'Entregador'
  ],
  'Pets e Veterinária': [
    'Passeador de cães', 'Banho e tosa', 'Adestrador', 'Pet sitter', 'Veterinário'
  ],
  'Costura e Lavanderia': [
    'Costureira', 'Ajuste de roupas', 'Lavanderia', 'Passadoria', 'Conserto de peças'
  ],
  'Piscinas e Lazer': [
    'Limpeza de piscina', 'Tratamento da água', 'Manutenção de bomba', 'Reparo de filtro'
  ],
  'Serviços para Empresas': [
    'Limpeza recorrente', 'Apoio operacional', 'Recepcionista', 'Zelador', 'Manutenção predial',
    'Monitoramento', 'Promotor', 'Representante comercial'
  ],
  'Outros': [
    'Serviços gerais', 'Freelance diverso', 'Dedetização', 'Outros serviços'
  ],
};

Map<String, List<String>> workerSpecialtyGroups() {
  final groups = <String, List<String>>{};

  for (final entry in categorySubservices.entries) {
    final seen = <String>{};
    final options = <String>[];

    void addOption(String value) {
      final clean = value.trim();
      if (clean.isEmpty) return;
      final key = clean.toLowerCase();
      if (seen.add(key)) options.add(clean);
    }

    for (final extra
        in workerSpecialtyExtrasByCategory[entry.key] ?? const <String>[]) {
      addOption(extra);
    }

    // Toda opção que o cliente pode solicitar também fica disponível
    // para o prestador selecionar como área/especialidade.
    for (final service in entry.value) {
      addOption(service);
    }

    groups[entry.key] = options;
  }

  return groups;
}

List<String> subservicesForCategory(String category) {
  return categorySubservices[category] ?? ['Serviço geral'];
}

String formatCoordinates(double? lat, double? lng) {
  if (lat == null || lng == null) return 'Não informado';
  return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

String jobNeighborhoodFromLocation(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  if (text.contains('•')) {
    return text.split('•').first.trim();
  }
  return '';
}

String jobCityFromLocation(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  final region = text.contains('•') ? text.split('•').last.trim() : text;
  final slash = region.lastIndexOf('/');
  if (slash > 0) return region.substring(0, slash).trim();
  return region;
}

String jobStateFromLocation(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  final region = text.contains('•') ? text.split('•').last.trim() : text;
  final slash = region.lastIndexOf('/');
  if (slash >= 0 && slash < region.length - 1) {
    return region.substring(slash + 1).trim().toUpperCase();
  }
  return '';
}

double? distanceKmBetween({
  required double? lat1,
  required double? lng1,
  required double? lat2,
  required double? lng2,
}) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;

  const earthRadiusKm = 6371.0;
  double toRadians(double value) => value * math.pi / 180.0;

  final dLat = toRadians(lat2 - lat1);
  final dLng = toRadians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRadians(lat1)) *
          math.cos(toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}


bool specialtyNeedsProfessionalCouncil(String text) {
  final normalized = text.toLowerCase().trim();
  const keywords = [
    'médico', 'medico', 'pediatra', 'cardiologista', 'dermato', 'ortoped',
    'gineco', 'psiquiatra', 'neurolog', 'urolog', 'endocrino', 'oftalmo',
    'otorrino', 'cirurg', 'oncolog', 'enfermeiro', 'enfermagem',
    'técnico de enfermagem', 'tecnico de enfermagem', 'fisioterapeuta',
    'psicólog', 'psicolog', 'dentista', 'odontolog', 'nutricion', 'farmac',
    'veterin', 'advog', 'arquiteto', 'engenheiro', 'vigilante', 'segurança privada',
    'seguranca privada'
  ];
  return keywords.any(normalized.contains);
}

String requiredCouncilForText(String text) {
  final normalized = text.toLowerCase().trim();
  if (normalized.contains('enferme')) return 'COREN';
  if (normalized.contains('técnico de enfermagem') || normalized.contains('tecnico de enfermagem')) return 'COREN';
  if (normalized.contains('fisioter')) return 'CREFITO';
  if (normalized.contains('psicólog') || normalized.contains('psicolog')) return 'CRP';
  if (normalized.contains('dentista') || normalized.contains('odontolog')) return 'CRO';
  if (normalized.contains('nutricion')) return 'CRN';
  if (normalized.contains('farmac')) return 'CRF';
  if (normalized.contains('veterin')) return 'CRMV';
  if (normalized.contains('advog')) return 'OAB';
  if (normalized.contains('arquiteto')) return 'CAU';
  if (normalized.contains('engenhe')) return 'CREA';
  if (normalized.contains('vigilante') || normalized.contains('segurança privada') || normalized.contains('seguranca privada')) return 'CNV';
  return 'CRM';
}

bool needsRqeForText(String text) {
  final normalized = text.toLowerCase().trim();
  const specialists = [
    'pediatra', 'cardiologista', 'dermato', 'ortoped', 'gineco',
    'psiquiatra', 'neurolog', 'urolog', 'endocrino', 'oftalmo',
    'otorrino', 'cirurg', 'oncolog'
  ];
  return specialists.any(normalized.contains);
}

String councilStatusLabel({required bool validated, required String councilType}) {
  if (councilType.trim().isEmpty) return 'Profissão não regulamentada';
  return validated ? '$councilType verificado' : '$councilType pendente';
}


Future<void> createNotificationForUser({
  required String userId,
  required String title,
  required String body,
  String referenceType = 'generic',
  String? referenceId,
}) async {
  try {
    await supabase.from('app_notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'is_read': false,
    });

    try {
      final session = supabase.auth.currentSession;
      await supabase.functions.invoke(
        'send-push-notification',
        headers: session == null
            ? {'apikey': supabaseAnonKey}
            : {
                'Authorization': 'Bearer ${session.accessToken}',
                'apikey': supabaseAnonKey,
              },
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'reference_type': referenceType,
          'reference_id': referenceId,
        },
      );
    } catch (_) {
      // Se o push falhar, a notificação interna continua salva.
    }
  } catch (_) {}
}

Future<void> notifyInterestedWorkersForJob({
  required String jobId,
  required String category,
  required String title,
  required String location,
}) async {
  try {
    final resumes = await supabase
        .from('worker_resumes')
        .select('worker_id, desired_categories, is_active')
        .eq('is_active', true);
    for (final item in (resumes as List)) {
      final map = Map<String, dynamic>.from(item);
      final workerId = (map['worker_id'] ?? '').toString();
      final raw = (map['desired_categories'] ?? []).toString().toLowerCase();
      if (workerId.isNotEmpty && raw.contains(category.toLowerCase())) {
        await createNotificationForUser(
          userId: workerId,
          title: 'Nova vaga na sua área',
          body: '$title • $location',
          referenceType: 'job',
          referenceId: jobId,
        );
      }
    }
  } catch (_) {}
}

Future<void> notifyCompaniesAboutResume({
  required String workerId,
  required String headline,
  required String categories,
}) async {
  try {
    final accesses = await supabase
        .from('company_resume_access')
        .select('company_id, is_active')
        .eq('is_active', true);
    for (final item in (accesses as List)) {
      final map = Map<String, dynamic>.from(item);
      final companyId = (map['company_id'] ?? '').toString();
      if (companyId.isNotEmpty) {
        await createNotificationForUser(
          userId: companyId,
          title: 'Novo currículo disponível',
          body: '$headline • $categories',
          referenceType: 'resume',
          referenceId: workerId,
        );
      }
    }
  } catch (_) {}
}

Uri? tryBuildMapsUri(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;
  return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(trimmed)}');
}

Future<void> openJobRouteInMaps(BuildContext context, JobModel job) async {
  Uri? uri;

  final exactAddress = (job.exactAddress ?? '').trim();
  final hasUsableExactAddress = exactAddress.isNotEmpty &&
      exactAddress.toLowerCase() != 'localização atual aproximada';

  if (hasUsableExactAddress) {
    final destinationParts = <String>[
      exactAddress,
      if (job.publicLocationLabel.trim().isNotEmpty)
        job.publicLocationLabel.trim(),
    ];
    final destination = destinationParts.join(', ');
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&travelmode=driving',
    );
  } else if (job.latitude != null && job.longitude != null) {
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${job.latitude},${job.longitude}&travelmode=driving',
    );
  } else if (job.publicLocationLabel.trim().isNotEmpty) {
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(job.publicLocationLabel)}&travelmode=driving',
    );
  }

  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este serviço ainda não tem endereço para iniciar rota.')),
      );
    }
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não consegui abrir o Google Maps neste celular.')),
    );
  }
}

Map<String, double?> extractCoordsFromGoogleMaps(String input) {
  final atMatch = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(input);
  if (atMatch != null) {
    return {
      'lat': double.tryParse(atMatch.group(1)!),
      'lng': double.tryParse(atMatch.group(2)!),
    };
  }
  final qMatch = RegExp(r'q=(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(input);
  if (qMatch != null) {
    return {
      'lat': double.tryParse(qMatch.group(1)!),
      'lng': double.tryParse(qMatch.group(2)!),
    };
  }
  final llMatch = RegExp(r'll=(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(input);
  if (llMatch != null) {
    return {
      'lat': double.tryParse(llMatch.group(1)!),
      'lng': double.tryParse(llMatch.group(2)!),
    };
  }
  return {'lat': null, 'lng': null};
}

class WorkerResumeModel {
  final String id;
  final String workerId;
  final String fullName;
  final String headline;
  final String summary;
  final String city;
  final String state;
  final String phone;
  final String desiredCategories;
  final String experience;
  final String education;
  final String availability;
  final bool isActive;
  final String professionalCouncilType;
  final String professionalCouncilNumber;
  final String professionalCouncilUf;
  final String professionalRqe;
  final bool professionalValidated;
  final String? professionalValidatedAt;
  final String validatedSeal;

  const WorkerResumeModel({
    required this.id,
    required this.workerId,
    required this.fullName,
    required this.headline,
    required this.summary,
    required this.city,
    required this.state,
    required this.phone,
    required this.desiredCategories,
    required this.experience,
    required this.education,
    required this.availability,
    required this.isActive,
    required this.professionalCouncilType,
    required this.professionalCouncilNumber,
    required this.professionalCouncilUf,
    required this.professionalRqe,
    required this.professionalValidated,
    required this.professionalValidatedAt,
    required this.validatedSeal,
  });

  factory WorkerResumeModel.fromMap(Map<String, dynamic> map) {
    return WorkerResumeModel(
      id: (map['id'] ?? '').toString(),
      workerId: (map['worker_id'] ?? '').toString(),
      fullName: (map['full_name'] ?? '').toString(),
      headline: (map['headline'] ?? '').toString(),
      summary: (map['summary'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      desiredCategories: (map['desired_categories'] ?? '').toString(),
      experience: (map['experience'] ?? '').toString(),
      education: (map['education'] ?? '').toString(),
      availability: (map['availability'] ?? '').toString(),
      isActive: map['is_active'] != false,
      professionalCouncilType: (map['professional_council_type'] ?? '').toString(),
      professionalCouncilNumber: (map['professional_council_number'] ?? '').toString(),
      professionalCouncilUf: (map['professional_council_uf'] ?? '').toString(),
      professionalRqe: (map['professional_rqe'] ?? '').toString(),
      professionalValidated: map['professional_validated'] == true,
      professionalValidatedAt: map['professional_validated_at']?.toString(),
      validatedSeal: (map['validated_seal'] ?? '').toString(),
    );
  }
}

class WorkerTrustModel {
  final String workerId;
  final String status;
  final DateTime? requestedAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final bool pioneerBadge;
  final int? pioneerNumber;
  final DateTime? pioneerGrantedAt;

  const WorkerTrustModel({
    required this.workerId,
    this.status = 'not_requested',
    this.requestedAt,
    this.verifiedAt,
    this.verifiedBy,
    this.pioneerBadge = false,
    this.pioneerNumber,
    this.pioneerGrantedAt,
  });

  bool get identityVerified => status == 'verified';
  bool get pending => status == 'pending';

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Em análise';
      case 'verified':
        return 'Identidade verificada';
      case 'rejected':
        return 'Revisão necessária';
      case 'not_requested':
      default:
        return 'Não verificado';
    }
  }

  factory WorkerTrustModel.fromMap(Map<String, dynamic> map) {
    return WorkerTrustModel(
      workerId: (map['worker_id'] ?? '').toString(),
      status: (map['status'] ?? 'not_requested').toString(),
      requestedAt: map['requested_at'] == null
          ? null
          : DateTime.tryParse(map['requested_at'].toString()),
      verifiedAt: map['verified_at'] == null
          ? null
          : DateTime.tryParse(map['verified_at'].toString()),
      verifiedBy: map['verified_by']?.toString(),
      pioneerBadge: map['pioneer_badge'] == true,
      pioneerNumber: map['pioneer_number'] is num
          ? (map['pioneer_number'] as num).toInt()
          : int.tryParse((map['pioneer_number'] ?? '').toString()),
      pioneerGrantedAt: map['pioneer_granted_at'] == null
          ? null
          : DateTime.tryParse(map['pioneer_granted_at'].toString()),
    );
  }
}

Future<WorkerTrustModel> loadWorkerTrust(String workerId) async {
  try {
    final response = await supabase
        .from('worker_identity_verifications')
        .select()
        .eq('worker_id', workerId)
        .maybeSingle();

    if (response == null) {
      return WorkerTrustModel(workerId: workerId);
    }
    return WorkerTrustModel.fromMap(Map<String, dynamic>.from(response));
  } catch (_) {
    // A tabela de verificação é complementar. Enquanto a migração não existir,
    // o restante do app continua funcionando normalmente.
    return WorkerTrustModel(workerId: workerId);
  }
}

class WorkerIdentityEvidenceModel {
  final String workerId;
  final String documentType;
  final String documentPath;
  final String selfiePath;
  final String reviewNote;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? consentAt;

  const WorkerIdentityEvidenceModel({
    required this.workerId,
    this.documentType = '',
    this.documentPath = '',
    this.selfiePath = '',
    this.reviewNote = '',
    this.submittedAt,
    this.reviewedAt,
    this.consentAt,
  });

  bool get hasRequiredFiles =>
      documentPath.trim().isNotEmpty && selfiePath.trim().isNotEmpty;

  factory WorkerIdentityEvidenceModel.fromMap(Map<String, dynamic> map) {
    return WorkerIdentityEvidenceModel(
      workerId: (map['worker_id'] ?? '').toString(),
      documentType: (map['document_type'] ?? '').toString(),
      documentPath: (map['document_path'] ?? '').toString(),
      selfiePath: (map['selfie_path'] ?? '').toString(),
      reviewNote: (map['review_note'] ?? '').toString(),
      submittedAt: map['submitted_at'] == null
          ? null
          : DateTime.tryParse(map['submitted_at'].toString()),
      reviewedAt: map['reviewed_at'] == null
          ? null
          : DateTime.tryParse(map['reviewed_at'].toString()),
      consentAt: map['consent_at'] == null
          ? null
          : DateTime.tryParse(map['consent_at'].toString()),
    );
  }
}

Future<WorkerIdentityEvidenceModel> loadWorkerIdentityEvidence(
  String workerId,
) async {
  try {
    final response = await supabase
        .from('worker_identity_evidence')
        .select()
        .eq('worker_id', workerId)
        .maybeSingle();

    if (response == null) {
      return WorkerIdentityEvidenceModel(workerId: workerId);
    }
    return WorkerIdentityEvidenceModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  } catch (_) {
    return WorkerIdentityEvidenceModel(workerId: workerId);
  }
}

Future<void> submitWorkerIdentityVerification({
  required String documentType,
  required String documentPath,
  required String selfiePath,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('Usuário não autenticado.');

  await supabase.rpc(
    'submit_worker_identity_verification',
    params: {
      'p_document_type': documentType,
      'p_document_path': documentPath,
      'p_selfie_path': selfiePath,
    },
  );
}


class PegaeFazFreeApp extends StatefulWidget {
  const PegaeFazFreeApp({super.key});

  @override
  State<PegaeFazFreeApp> createState() => _PegaeFazFreeAppState();
}

class _PegaeFazFreeAppState extends State<PegaeFazFreeApp> {
  bool showResetPasswordPage = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupPushNotificationsForCurrentUser();
    });

    supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          showResetPasswordPage = true;
        });
        return;
      }

      setupPushNotificationsForCurrentUser();
      setState(() {});
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'PegaeFazFree';
      final body = message.notification?.body ?? 'Nova notificação recebida.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title\n$body')),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      setupPushNotificationsForCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PegaeFazFree',
      theme: ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: const Color(0xFFF6F2EF),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF4C61D)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4C61D),
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: showResetPasswordPage
          ? ResetPasswordPage(
              onDone: () async {
                await supabase.auth.signOut();
                if (mounted) {
                  setState(() {
                    showResetPasswordPage = false;
                  });
                }
              },
            )
          : supabase.auth.currentSession == null
              ? const AuthPage()
              : const LocalAuthGate(child: MainShell()),
    );
  }
}


class LocalAuthGate extends StatefulWidget {
  final Widget child;

  const LocalAuthGate({super.key, required this.child});

  @override
  State<LocalAuthGate> createState() => _LocalAuthGateState();
}

class _LocalAuthGateState extends State<LocalAuthGate> with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();
  bool unlocked = false;
  bool checking = true;
  bool authenticating = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted && supabase.auth.currentSession != null) {
        setState(() => unlocked = false);
      }
    }
  }

  Future<void> unlock() async {
    if (authenticating) return;
    final session = supabase.auth.currentSession;
    if (session == null) {
      if (mounted) {
        setState(() {
          unlocked = true;
          checking = false;
          errorText = null;
        });
      }
      return;
    }

    setState(() {
      authenticating = true;
      checking = true;
      errorText = null;
    });

    try {
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (!supported && !canCheck) {
        if (mounted) {
          setState(() {
            unlocked = true;
            checking = false;
            authenticating = false;
          });
        }
        return;
      }

      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Confirme sua identidade para abrir o PegaeFazFree.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        unlocked = didAuthenticate;
        checking = false;
        authenticating = false;
        errorText = didAuthenticate ? null : 'Desbloqueio cancelado.';
      });
    } catch (e) {
      // Se o aparelho não estiver configurado corretamente, o app não fica preso.
      if (!mounted) return;
      setState(() {
        unlocked = true;
        checking = false;
        authenticating = false;
        errorText = null;
      });
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (unlocked) return widget.child;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 62, color: Colors.black87),
                  const SizedBox(height: 14),
                  const Text(
                    'PegaeFazFree bloqueado',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use a digital, face, PIN, senha ou padrão do celular para continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.35),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(errorText!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: checking || authenticating ? null : unlock,
                      icon: checking || authenticating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.lock_open),
                      label: Text(checking || authenticating ? 'Verificando...' : 'Desbloquear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4C61D),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair desta conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class JobModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final String subservice;
  final String? exactAddress;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;
  final double price;
  final String status;
  final String clientId;
  final String? workerId;
  final DateTime? createdAt;

  // 🔥 NOVO: PAGAMENTO
  final String paymentStatus;
  final String escrowStatus;
  final String? paymentPreferenceId;
  final String? paymentIdMp;
  final DateTime? paidAt;
  final DateTime? concludedAt;

  // Comprovação enviada pelo prestador ao marcar "Trabalho concluído".
  // Não libera dinheiro automaticamente; serve como prova para cliente/admin.
  final String? completionPhotoUrl;
  final DateTime? workerCompletedAt;
  final String completionStatus;

  String get neighborhood => jobNeighborhoodFromLocation(location);
  String get city => jobCityFromLocation(location);
  String get state => jobStateFromLocation(location);

  String get publicLocationLabel {
    final cityName = city.trim();
    final stateName = state.trim();
    final neighborhoodName = neighborhood.trim();

    if (neighborhoodName.isNotEmpty && cityName.isNotEmpty) {
      return '$neighborhoodName • $cityName${stateName.isNotEmpty ? '/$stateName' : ''}';
    }
    if (cityName.isNotEmpty) {
      return '$cityName${stateName.isNotEmpty ? '/$stateName' : ''}';
    }
    return location.trim().isEmpty ? 'Local não informado' : location.trim();
  }

  const JobModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.subservice,
    required this.exactAddress,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.price,
    required this.status,
    required this.clientId,
    required this.workerId,
    required this.createdAt,

    required this.paymentStatus,
    required this.escrowStatus,
    required this.paymentPreferenceId,
    required this.paymentIdMp,
    required this.paidAt,
    required this.concludedAt,
    required this.completionPhotoUrl,
    required this.workerCompletedAt,
    required this.completionStatus,
  });

  factory JobModel.fromMap(Map<String, dynamic> map) {
    return JobModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      category: (map['category'] ?? 'Outros').toString(),
      location: (map['location'] ?? '').toString(),
      subservice: (map['subservice'] ?? map['subcategory'] ?? '').toString(),
      exactAddress: map['exact_address']?.toString(),
      photoUrl: map['photo_url']?.toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      price: ((map['price'] ?? 0) as num).toDouble(),
      status: (map['status'] ?? 'open').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      workerId: map['worker_id']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),

      // 🔥 IMPORTANTE
      paymentStatus: (map['payment_status'] ?? 'unpaid').toString(),
      escrowStatus: (map['escrow_status'] ?? 'not_started').toString(),
      paymentPreferenceId: map['payment_preference_id']?.toString(),
      paymentIdMp: map['payment_id_mp']?.toString(),
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.tryParse(map['paid_at'].toString()),
      concludedAt: map['concluded_at'] == null
          ? null
          : DateTime.tryParse(map['concluded_at'].toString()),
      completionPhotoUrl: map['completion_photo_url']?.toString(),
      workerCompletedAt: map['worker_completed_at'] == null
          ? null
          : DateTime.tryParse(map['worker_completed_at'].toString()),
      completionStatus: (map['completion_status'] ?? 'pending').toString(),
    );
  }
}
class ReviewModel {
  final String id;
  final String jobId;
  final String reviewerId;
  final String reviewedId;
  final double rating;
  final String comment;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.reviewedId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: (map['id'] ?? '').toString(),
      jobId: (map['job_id'] ?? '').toString(),
      reviewerId: (map['reviewer_id'] ?? '').toString(),
      reviewedId: (map['reviewed_id'] ?? '').toString(),
      rating: ((map['rating'] ?? 0) as num).toDouble(),
      comment: (map['comment'] ?? '').toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}

class MessageModel {
  final String id;
  final String jobId;
  final String senderId;
  final String text;
  final bool isRead;
  final DateTime? createdAt;

  const MessageModel({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: (map['id'] ?? '').toString(),
      jobId: (map['job_id'] ?? '').toString(),
      senderId: (map['sender_id'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      isRead: map['is_read'] == true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}

class ProfileModel {
  final String id;
  final String name;
  final String role;
  final String? phone;
  final String? cep;
  final String? address;
  final String? number;
  final String? complement;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? specialty;
  final String? workerCnpj;
  final String? fotoUrl;
  final String? companyLegalName;
  final String? companyTradeName;
  final String? companyCnpj;
  final String? companyResponsible;
  final String? companyEmail;
  final String? companyAddress;
  final String? companyNumber;
  final String? companyComplement;
  final String? companyNeighborhood;
  final String? companyCity;
  final String? companyState;
  final bool companyVerified;
  final bool womanSpaceEnabled;
  final bool womanSpaceVisible;
  final bool womanSpaceReceiveNotifications;

  // Campos legados do Mercado Pago preservados apenas por compatibilidade com o banco.
  // O fluxo ativo de recebimentos usa a conta conectada do novo provedor de pagamentos.
  final bool mpConnected;
  final String? mpUserId;

  final String? stripeAccountId;
  final String stripeAccountStatus;
  final bool stripeDetailsSubmitted;
  final bool stripeChargesEnabled;
  final bool stripePayoutsEnabled;
  final DateTime? stripeOnboardingCompletedAt;

  bool get hasReceivingAccount =>
      stripeAccountId != null && stripeAccountId!.trim().isNotEmpty;

  bool get receivingReady =>
      stripeDetailsSubmitted && stripeChargesEnabled && stripePayoutsEnabled;

  bool get receivingUnderReview =>
      hasReceivingAccount && stripeDetailsSubmitted && !receivingReady;

  String get receivingStatusLabel {
    if (receivingReady) return 'Ativo';
    if (receivingUnderReview) return 'Em análise';
    if (hasReceivingAccount) return 'Configuração pendente';
    return 'Não conectado';
  }

  String get receivingButtonLabel {
    if (receivingReady) return 'Conta de recebimento conectada';
    if (receivingUnderReview) return 'Conta conectada • em análise';
    if (hasReceivingAccount) return 'Continuar configuração';
    return 'Conectar para receber';
  }

  const ProfileModel({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.cep,
    this.address,
    this.number,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
    required this.specialty,
    this.workerCnpj,
    required this.mpConnected,
    required this.mpUserId,
    this.stripeAccountId,
    this.stripeAccountStatus = 'not_connected',
    this.stripeDetailsSubmitted = false,
    this.stripeChargesEnabled = false,
    this.stripePayoutsEnabled = false,
    this.stripeOnboardingCompletedAt,
    this.fotoUrl,
    this.companyLegalName,
    this.companyTradeName,
    this.companyCnpj,
    this.companyResponsible,
    this.companyEmail,
    this.companyAddress,
    this.companyNumber,
    this.companyComplement,
    this.companyNeighborhood,
    this.companyCity,
    this.companyState,
    this.companyVerified = false,
    this.womanSpaceEnabled = false,
    this.womanSpaceVisible = false,
    this.womanSpaceReceiveNotifications = true,
  });

  ProfileModel copyWith({
    String? id,
    String? name,
    String? role,
    String? phone,
    String? cep,
    String? address,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? specialty,
    String? workerCnpj,
    String? fotoUrl,
    bool? mpConnected,
    String? mpUserId,
    String? stripeAccountId,
    String? stripeAccountStatus,
    bool? stripeDetailsSubmitted,
    bool? stripeChargesEnabled,
    bool? stripePayoutsEnabled,
    DateTime? stripeOnboardingCompletedAt,
    String? companyLegalName,
    String? companyTradeName,
    String? companyCnpj,
    String? companyResponsible,
    String? companyEmail,
    String? companyAddress,
    String? companyNumber,
    String? companyComplement,
    String? companyNeighborhood,
    String? companyCity,
    String? companyState,
    bool? companyVerified,
    bool? womanSpaceEnabled,
    bool? womanSpaceVisible,
    bool? womanSpaceReceiveNotifications,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      cep: cep ?? this.cep,
      address: address ?? this.address,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      specialty: specialty ?? this.specialty,
      workerCnpj: workerCnpj ?? this.workerCnpj,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      mpConnected: mpConnected ?? this.mpConnected,
      mpUserId: mpUserId ?? this.mpUserId,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      stripeAccountStatus: stripeAccountStatus ?? this.stripeAccountStatus,
      stripeDetailsSubmitted: stripeDetailsSubmitted ?? this.stripeDetailsSubmitted,
      stripeChargesEnabled: stripeChargesEnabled ?? this.stripeChargesEnabled,
      stripePayoutsEnabled: stripePayoutsEnabled ?? this.stripePayoutsEnabled,
      stripeOnboardingCompletedAt:
          stripeOnboardingCompletedAt ?? this.stripeOnboardingCompletedAt,
      companyLegalName: companyLegalName ?? this.companyLegalName,
      companyTradeName: companyTradeName ?? this.companyTradeName,
      companyCnpj: companyCnpj ?? this.companyCnpj,
      companyResponsible: companyResponsible ?? this.companyResponsible,
      companyEmail: companyEmail ?? this.companyEmail,
      companyAddress: companyAddress ?? this.companyAddress,
      companyNumber: companyNumber ?? this.companyNumber,
      companyComplement: companyComplement ?? this.companyComplement,
      companyNeighborhood: companyNeighborhood ?? this.companyNeighborhood,
      companyCity: companyCity ?? this.companyCity,
      companyState: companyState ?? this.companyState,
      companyVerified: companyVerified ?? this.companyVerified,
      womanSpaceEnabled: womanSpaceEnabled ?? this.womanSpaceEnabled,
      womanSpaceVisible: womanSpaceVisible ?? this.womanSpaceVisible,
      womanSpaceReceiveNotifications: womanSpaceReceiveNotifications ?? this.womanSpaceReceiveNotifications,
    );
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Usuário').toString(),
      role: (map['role'] ?? roleClient).toString(),
      phone: map['phone']?.toString(),
      cep: map['cep']?.toString(),
      address: map['address']?.toString(),
      number: map['number']?.toString(),
      complement: map['complement']?.toString(),
      neighborhood: map['neighborhood']?.toString(),
      city: map['city']?.toString(),
      state: map['state']?.toString(),
      specialty: map['specialty']?.toString(),
      workerCnpj: map['worker_cnpj']?.toString(),
      mpConnected: map['mp_connected'] == true,
      mpUserId: map['mp_user_id']?.toString(),
      stripeAccountId: map['stripe_account_id']?.toString(),
      stripeAccountStatus: (map['stripe_account_status'] ?? 'not_connected').toString(),
      stripeDetailsSubmitted: map['stripe_details_submitted'] == true,
      stripeChargesEnabled: map['stripe_charges_enabled'] == true,
      stripePayoutsEnabled: map['stripe_payouts_enabled'] == true,
      stripeOnboardingCompletedAt: map['stripe_onboarding_completed_at'] == null
          ? null
          : DateTime.tryParse(map['stripe_onboarding_completed_at'].toString()),
      fotoUrl: map['foto_url']?.toString(),
      companyLegalName: map['company_legal_name']?.toString(),
      companyTradeName: map['company_trade_name']?.toString(),
      companyCnpj: map['company_cnpj']?.toString(),
      companyResponsible: map['company_responsible']?.toString(),
      companyEmail: map['company_email']?.toString(),
      companyAddress: map['company_address']?.toString(),
      companyNumber: map['company_number']?.toString(),
      companyComplement: map['company_complement']?.toString(),
      companyNeighborhood: map['company_neighborhood']?.toString(),
      companyCity: map['company_city']?.toString(),
      companyState: map['company_state']?.toString(),
      companyVerified: map['company_verified'] == true,
      womanSpaceEnabled: boolFromDynamic(map['woman_space_enabled']),
      womanSpaceVisible: boolFromDynamic(map['woman_space_visible']),
      womanSpaceReceiveNotifications: boolFromDynamic(
        map['woman_space_receive_notifications'],
        defaultValue: true,
      ),
    );
  }
}

class ProposalModel {
  final String id;
  final String jobId;
  final String workerId;
  final String clientId;
  final String status;
  final double amount;
  final String message;
  final bool isCounter;
  final DateTime? createdAt;

  const ProposalModel({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.clientId,
    required this.status,
    required this.amount,
    required this.message,
    required this.isCounter,
    required this.createdAt,
  });

  factory ProposalModel.fromMap(Map<String, dynamic> map) {
    return ProposalModel(
      id: (map['id'] ?? '').toString(),
      jobId: (map['job_id'] ?? '').toString(),
      workerId: (map['worker_id'] ?? '').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      amount: ((map['amount'] ?? 0) as num).toDouble(),
      message: (map['message'] ?? '').toString(),
      isCounter: map['is_counter'] == true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}

class SafetyCheckResult {
  final bool blocked;
  final bool flagged;
  final String reason;

  const SafetyCheckResult({
    required this.blocked,
    required this.flagged,
    required this.reason,
  });
}

class EmbeddedSafetyAI {
  static const List<String> blockedTerms = [
    'pix antecipado',
    'senha do cartão',
    'arma',
    'ameaça',
    'explosivo',
    'golpe',
  ];

  static const List<String> flaggedTerms = [
    'whatsapp',
    'documento',
    'rg',
    'cpf',
    'pix',
    'dinheiro por fora',
    'endereço completo',
  ];

  static SafetyCheckResult inspect(String text) {
    final normalized = text.toLowerCase().trim();

    for (final term in blockedTerms) {
      if (normalized.contains(term)) {
        return SafetyCheckResult(
          blocked: true,
          flagged: true,
          reason: 'Conteúdo potencialmente perigoso detectado: $term',
        );
      }
    }

    for (final term in flaggedTerms) {
      if (normalized.contains(term)) {
        return SafetyCheckResult(
          blocked: false,
          flagged: true,
          reason: 'Conteúdo sensível detectado: $term',
        );
      }
    }

    return const SafetyCheckResult(
      blocked: false,
      flagged: false,
      reason: '',
    );
  }

  static Future<void> registerEvent({
    required String sourceType,
    required String sourceId,
    required String content,
    required SafetyCheckResult result,
  }) async {
    if (!result.flagged) return;
    try {
      await supabase.from('safety_events').insert({
        'source_type': sourceType,
        'source_id': sourceId,
        'content': content,
        'blocked': result.blocked,
        'reason': result.reason,
      });
    } catch (_) {
      // tabela opcional
    }
  }
 }

const List<String> userReportReasons = [
  'Fraude ou golpe',
  'Comportamento ofensivo',
  'Tentativa de pagamento fora da plataforma',
  'Conteúdo impróprio',
  'Assédio ou ameaça',
  'Spam',
  'Outro',
];

String userReportStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'reviewing':
      return 'Em análise';
    case 'resolved':
      return 'Resolvida';
    case 'dismissed':
      return 'Descartada';
    case 'pending':
    default:
      return 'Pendente';
  }
}

Color userReportStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'reviewing':
      return Colors.blue;
    case 'resolved':
      return Colors.green;
    case 'dismissed':
      return Colors.grey;
    case 'pending':
    default:
      return Colors.orange;
  }
}

Future<void> submitUserReport({
  required String reportedUserId,
  required String reason,
  required String source,
  String? details,
  String? jobId,
  String? messageId,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('Usuário não autenticado.');

  final targetId = reportedUserId.trim();
  if (targetId.isEmpty) {
    throw Exception('Não foi possível identificar o usuário denunciado.');
  }
  if (targetId == user.id) {
    throw Exception('Você não pode denunciar a própria conta.');
  }

  await supabase.from('user_reports').insert({
    'reporter_id': user.id,
    'reported_user_id': targetId,
    'reason': reason.trim(),
    'details': (details ?? '').trim().isEmpty ? null : details!.trim(),
    'source': source.trim(),
    'job_id': (jobId ?? '').trim().isEmpty ? null : jobId!.trim(),
    'message_id': (messageId ?? '').trim().isEmpty ? null : messageId!.trim(),
    'status': 'pending',
  });
}

Future<bool> showUserReportDialog(
  BuildContext context, {
  required String reportedUserId,
  required String source,
  String? reportedDisplayName,
  String? jobId,
  String? messageId,
}) async {
  final currentUser = supabase.auth.currentUser;
  if (currentUser == null) return false;

  final targetId = reportedUserId.trim();
  if (targetId.isEmpty || targetId == currentUser.id) return false;

  final detailsController = TextEditingController();
  String? selectedReason;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Denunciar usuário'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Você está denunciando ${reportedDisplayName?.trim().isNotEmpty == true ? reportedDisplayName!.trim() : 'este usuário'}. A denúncia será enviada para análise da equipe PegaeFazFree.',
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    isExpanded: true,
                    decoration: fieldDecoration('Motivo da denúncia'),
                    items: userReportReasons
                        .map(
                          (reason) => DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedReason = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: fieldDecoration('Detalhes (opcional)'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A denúncia não bloqueia nem exclui a conta automaticamente. A equipe analisará o caso.',
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: selectedReason == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Enviar denúncia'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    },
  );

  final details = detailsController.text.trim();
  detailsController.dispose();
  if (confirmed != true || selectedReason == null) return false;

  try {
    await submitUserReport(
      reportedUserId: targetId,
      reason: selectedReason!,
      source: source,
      details: details,
      jobId: jobId,
      messageId: messageId,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Denúncia enviada para análise da equipe PegaeFazFree.'),
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar a denúncia: $e')),
      );
    }
    return false;
  }
}

Future<void> createOrUpdateProposal({
  required JobModel job,
  required double amount,
  required String message,
  required bool isCounter,
  String? targetWorkerId,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('Usuário não autenticado.');

  final safety = EmbeddedSafetyAI.inspect(message);
  if (safety.blocked) {
    throw Exception(safety.reason);
  }

  final resolvedWorkerId = isCounter
      ? (targetWorkerId ?? job.workerId ?? user.id)
      : user.id;

  if (resolvedWorkerId.trim().isEmpty) {
    throw Exception('Não foi possível identificar o prestador da proposta.');
  }

  await supabase.from('proposals').insert({
    'job_id': job.id,
    'worker_id': resolvedWorkerId,
    'client_id': job.clientId,
    'amount': amount,
    'message': message,
    'status': 'pending',
    'is_counter': isCounter,
  });

  await EmbeddedSafetyAI.registerEvent(
    sourceType: 'proposal',
    sourceId: job.id,
    content: message,
    result: safety,
  );

  final notificationUserId = isCounter && user.id == job.clientId
      ? resolvedWorkerId
      : job.clientId;

  await createNotificationForUser(
    userId: notificationUserId,
    title: isCounter ? 'Nova contra-proposta recebida' : 'Nova proposta recebida',
    body: '${job.title} • ${money(amount)}',
    referenceType: 'proposal',
    referenceId: job.id,
  );
}

Future<List<ProposalModel>> loadJobProposals(String jobId) async {
  final response = await supabase
      .from('proposals')
      .select()
      .eq('job_id', jobId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => ProposalModel.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

String proposalStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pendente';
    case 'accepted':
      return 'Aceita';
    case 'rejected':
      return 'Recusada';
    default:
      return status;
  }
}

Color proposalStatusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.orange;
    case 'accepted':
      return Colors.green;
    case 'rejected':
      return Colors.redAccent;
    default:
      return Colors.black54;
  }
}

String money(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

String formatDate(DateTime? dt) {
  if (dt == null) return '';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year.toString();
  return '$d/$m/$y';
}

String statusLabel(String status) {
  switch (status) {
    case 'open':
      return 'Aberto';
    case 'proposal_sent':
      return 'Com proposta aceita';
    case 'in_progress':
      return 'Em andamento';
    case 'done':
      return 'Concluído';
    case 'cancelled':
      return 'Cancelado';
    default:
      return status;
  }
}



Color statusColor(String status) {
  switch (status) {
    case 'open':
      return Colors.orange;
    case 'proposal_sent':
      return Colors.deepOrange;
    case 'in_progress':
      return Colors.blue;
    case 'done':
      return Colors.green;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String paymentStatusLabel(String status) {
  switch (status) {
    case 'unpaid':
      return 'Não pago';
    case 'pending':
      return 'Pagamento pendente';
    case 'paid':
      return 'Pagamento aprovado';
    case 'failed':
      return 'Pagamento falhou';
    case 'refunded':
      return 'Reembolsado';
    default:
      return status;
  }
}

Color paymentStatusColor(String status) {
  switch (status) {
    case 'unpaid':
      return Colors.grey;
    case 'pending':
      return Colors.orange;
    case 'paid':
      return Colors.green;
    case 'failed':
      return Colors.red;
    case 'refunded':
      return Colors.purple;
    default:
      return Colors.black45;
  }
}

String escrowStatusLabel(String status) {
  switch (status) {
    case 'not_started':
      return 'Repasse não iniciado';
    case 'held':
      return 'Pagamento acompanhado';
    case 'released':
      return 'Repasse realizado';
    case 'cancelled':
      return 'Pagamento encerrado';
    default:
      return status;
  }
}

Color escrowStatusColor(String status) {
  switch (status) {
    case 'not_started':
      return Colors.grey;
    case 'held':
      return Colors.blue;
    case 'released':
      return Colors.green;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.black45;
  }
}

double calculatePlatformFee(
  double amount, {
  double feePercent = 0,
}) {
  final safePercent = feePercent.clamp(0, 100).toDouble();
  return double.parse(
    (amount * (safePercent / 100)).toStringAsFixed(2),
  );
}

double calculateWorkerNet(
  double amount, {
  double feePercent = 0,
}) {
  return double.parse(
    (amount - calculatePlatformFee(amount, feePercent: feePercent))
        .toStringAsFixed(2),
  );
}

Future<double> getEffectivePlatformFeePercent() async {
  try {
    final response = await supabase
        .from('app_settings')
        .select('platform_fee_percent')
        .limit(1)
        .maybeSingle();

    if (response != null) {
      final raw = response['platform_fee_percent'];
      final parsed = raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString().replaceAll(',', '.') ?? '');

      if (parsed != null && parsed.isFinite && parsed >= 0 && parsed <= 50) {
        return parsed;
      }
    }
  } catch (_) {
    // Fallback seguro abaixo.
  }

  // Se a configuração remota não puder ser lida, o app exibe 0%.
  // O backend é a fonte definitiva do cálculo financeiro.
  return 0;
}

Future<Map<String, dynamic>?> getAppSettings() async {
  try {
    final response = await supabase.from('app_settings').select().limit(1).maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  } catch (_) {
    return null;
  }
}

Future<void> refreshAllVisiblePayments(List<JobModel> jobs) async {
  for (final job in jobs) {
    if (job.paymentStatus == 'paid' || job.paymentStatus == 'pending') {
      await syncJobPaymentStatus(job.id);
    }
  }
}

Future<bool> hasAcceptedProposalForJob(String jobId) async {
  try {
    final proposal = await supabase
        .from('proposals')
        .select('id,status')
        .eq('job_id', jobId)
        .eq('status', 'accepted')
        .limit(1)
        .maybeSingle();
    return proposal != null;
  } catch (_) {
    return false;
  }
}

IconData categoryIcon(String category) {
  final c = category.toLowerCase().trim();

  if (c == 'todos') return Icons.apps_rounded;

  if (c.contains('reformas') || c.contains('reparo')) return Icons.handyman_rounded;
  if (c == 'limpeza' || c.contains('faxina') || c.contains('higieniza') || c.contains('lavagem')) return Icons.cleaning_services_rounded;
  if (c.contains('serviços domésticos') || c.contains('domestico') || c.contains('doméstico')) return Icons.home_rounded;
  if (c.contains('assistência técnica') || c.contains('assistencia tecnica')) return Icons.build_circle_rounded;
  if (c.contains('design') || c.contains('tecnologia')) return Icons.laptop_mac_rounded;
  if (c.contains('eventos') || c.contains('hospitalidade')) return Icons.celebration_rounded;
  if (c.contains('moda') || c.contains('beleza')) return Icons.face_retouching_natural_rounded;
  if (c.contains('saúde') || c.contains('saude') || c.contains('bem-estar')) return Icons.health_and_safety_rounded;
  if (c.contains('aulas') || c.contains('reforço') || c.contains('reforco') || c.contains('escolar')) return Icons.school_rounded;
  if (c.contains('consultoria') || c.contains('escritório') || c.contains('escritorio')) return Icons.business_center_rounded;
  if (c.contains('automóveis') || c.contains('automoveis') || c.contains('veículos') || c.contains('veiculos')) return Icons.directions_car_rounded;
  if (c.contains('segurança') || c.contains('seguranca') || c.contains('monitoramento')) return Icons.security_rounded;
  if (c.contains('alimentos') || c.contains('gastronomia')) return Icons.restaurant_rounded;
  if (c.contains('jardinagem') || c.contains('áreas externas') || c.contains('areas externas')) return Icons.yard_rounded;
  if (c.contains('mudanças') || c.contains('mudancas') || c.contains('fretes')) return Icons.local_shipping_rounded;
  if (c.contains('pets') || c.contains('veterinária') || c.contains('veterinaria')) return Icons.pets_rounded;
  if (c.contains('costura') || c.contains('lavanderia')) return Icons.local_laundry_service_rounded;
  if (c.contains('piscinas') || c.contains('lazer')) return Icons.pool_rounded;
  if (c.contains('empresas')) return Icons.apartment_rounded;

  if (c.contains('pedreiro') || c.contains('servente') || c.contains('mestre de obras') || c.contains('azulejista') || c.contains('drywall') || c.contains('gesseiro')) return Icons.construction_rounded;
  if (c.contains('marido de aluguel') || c.contains('montador') || c.contains('reparo') || c.contains('manutenção predial') || c.contains('manutencao predial')) return Icons.handyman_rounded;
  if (c.contains('eletricista') || c.contains('elétrica') || c.contains('eletrica')) return Icons.electrical_services_rounded;
  if (c.contains('encanador') || c.contains('hidrául') || c.contains('hidraul') || c.contains('piscineiro')) return Icons.plumbing_rounded;
  if (c.contains('pintor') || c.contains('pintura')) return Icons.format_paint_rounded;
  if (c.contains('chaveiro')) return Icons.key_rounded;
  if (c.contains('soldador') || c.contains('serralheiro')) return Icons.build_rounded;
  if (c.contains('marceneiro') || c.contains('móveis') || c.contains('moveis')) return Icons.weekend_rounded;
  if (c.contains('vidraceiro') || c.contains('vidro')) return Icons.grid_view_rounded;
  if (c.contains('telhadista') || c.contains('calheiro')) return Icons.home_repair_service_rounded;

  if (c.contains('diarista') || c.contains('faxineira') || c.contains('camareira') || c.contains('governanta') || c.contains('limpeza')) return Icons.cleaning_services_rounded;
  if (c.contains('babá') || c.contains('baba') || c.contains('cuidador')) return Icons.child_care_rounded;
  if (c.contains('cozinheira')) return Icons.restaurant_rounded;
  if (c.contains('passadeira') || c.contains('lavadeira')) return Icons.local_laundry_service_rounded;
  if (c.contains('personal organizer') || c.contains('organização') || c.contains('organizacao')) return Icons.inventory_rounded;

  if (c.contains('ar-condicionado') || c.contains('ar condicionado')) return Icons.ac_unit_rounded;
  if (c.contains('celular') || c.contains('smartphone')) return Icons.smartphone_rounded;
  if (c.contains('computador') || c.contains('notebook') || c.contains('suporte técnico') || c.contains('suporte tecnico') || c.contains('redes e internet')) return Icons.computer_rounded;
  if (c.contains('tv') || c.contains('eletrodoméstico') || c.contains('eletrodomestico') || c.contains('geladeira')) return Icons.settings_applications_rounded;

  if (c.contains('logo') || c.contains('designer') || c.contains('gráfico') || c.contains('grafico')) return Icons.brush_rounded;
  if (c.contains('social media') || c.contains('marketing') || c.contains('tráfego') || c.contains('trafego')) return Icons.campaign_rounded;
  if (c.contains('vídeo') || c.contains('video') || c.contains('edição') || c.contains('edicao')) return Icons.movie_creation_rounded;
  if (c.contains('site') || c.contains('aplicativo') || c.contains('programação') || c.contains('programacao') || c.contains('desenvolvedor')) return Icons.code_rounded;

  if (c.contains('garçom') || c.contains('garcom') || c.contains('bartender') || c.contains('buffet') || c.contains('churrasqueiro')) return Icons.room_service_rounded;
  if (c.contains('fotógrafo') || c.contains('fotografo') || c.contains('filmagem')) return Icons.photo_camera_rounded;
  if (c.contains('dj') || c.contains('som') || c.contains('iluminação') || c.contains('iluminacao')) return Icons.music_note_rounded;
  if (c.contains('decoração') || c.contains('decoracao')) return Icons.auto_awesome_rounded;
  if (c.contains('recepcionista') || c.contains('promotor') || c.contains('panfletagem')) return Icons.badge_rounded;

  if (c.contains('cabeleireiro') || c.contains('barbeiro')) return Icons.content_cut_rounded;
  if (c.contains('maqui') || c.contains('sobrancelha') || c.contains('lash') || c.contains('esteticista') || c.contains('depilação') || c.contains('depilacao')) return Icons.face_retouching_natural_rounded;
  if (c.contains('manicure') || c.contains('pedicure') || c.contains('podóloga') || c.contains('podologa')) return Icons.spa_rounded;

  if (c.contains('médico') || c.contains('medico') || c.contains('pediatra') || c.contains('cardiologista') || c.contains('enfermeiro') || c.contains('enfermagem')) return Icons.medical_services_rounded;
  if (c.contains('fisioterapeuta') || c.contains('massoterapeuta')) return Icons.accessibility_new_rounded;
  if (c.contains('psicólogo') || c.contains('psicologo')) return Icons.psychology_rounded;
  if (c.contains('nutricionista')) return Icons.restaurant_menu_rounded;
  if (c.contains('dentista')) return Icons.medical_services_rounded;
  if (c.contains('veterinário') || c.contains('veterinario')) return Icons.pets_rounded;

  if (c.contains('professor') || c.contains('aula') || c.contains('educação') || c.contains('educacao') || c.contains('enem') || c.contains('concurso')) return Icons.school_rounded;
  if (c.contains('advogado')) return Icons.gavel_rounded;
  if (c.contains('contador') || c.contains('financeiro')) return Icons.calculate_rounded;
  if (c.contains('consultor') || c.contains('representante') || c.contains('despachante') || c.contains('corretor')) return Icons.business_center_rounded;
  if (c.contains('tradutor')) return Icons.translate_rounded;
  if (c.contains('arquiteto')) return Icons.account_balance_rounded;
  if (c.contains('engenheiro')) return Icons.engineering_rounded;

  if (c.contains('mecânico') || c.contains('mecanico') || c.contains('funilaria') || c.contains('chapeador') || c.contains('auto elétrica') || c.contains('auto eletrica')) return Icons.car_repair_rounded;
  if (c.contains('borracheiro')) return Icons.build_rounded;
  if (c.contains('guincho')) return Icons.local_shipping_rounded;
  if (c.contains('higienização automotiva') || c.contains('estética automotiva') || c.contains('estetica automotiva')) return Icons.local_car_wash_rounded;
  if (c.contains('motorista')) return Icons.drive_eta_rounded;

  if (c.contains('vigia') || c.contains('vigilante') || c.contains('porteiro') || c.contains('guarda') || c.contains('segurança') || c.contains('seguranca')) return Icons.security_rounded;
  if (c.contains('câmera') || c.contains('camera') || c.contains('alarme') || c.contains('cerca elétrica') || c.contains('cerca eletrica') || c.contains('portão') || c.contains('portao')) return Icons.videocam_rounded;

  if (c.contains('açougueiro') || c.contains('acougueiro')) return Icons.restaurant_rounded;
  if (c.contains('confeiteiro') || c.contains('padeiro')) return Icons.restaurant_rounded;
  if (c.contains('sommelier')) return Icons.wine_bar_rounded;
  if (c.contains('jardineiro') || c.contains('paisagista') || c.contains('poda') || c.contains('roçada') || c.contains('rocada') || c.contains('terreno')) return Icons.yard_rounded;
  if (c.contains('mudança') || c.contains('mudanca') || c.contains('frete') || c.contains('carreto')) return Icons.local_shipping_rounded;
  if (c.contains('motoboy') || c.contains('entregador')) return Icons.delivery_dining_rounded;
  if (c.contains('passeador') || c.contains('banho e tosa') || c.contains('adestrador') || c.contains('pet sitter')) return Icons.pets_rounded;
  if (c.contains('costureira') || c.contains('roupas') || c.contains('costura')) return Icons.checkroom_rounded;
  if (c.contains('lavanderia') || c.contains('passadoria')) return Icons.local_laundry_service_rounded;
  if (c.contains('piscina') || c.contains('bomba') || c.contains('filtro')) return Icons.pool_rounded;
  if (c.contains('dedetiza')) return Icons.bug_report_rounded;
  if (c.contains('zelador')) return Icons.apartment_rounded;

  return Icons.miscellaneous_services_rounded;
}

Future<void> ensureProfileExists({
  String? desiredRole,
  String? desiredName,
  String? desiredPhone,
  String? desiredCep,
  String? desiredAddress,
  String? desiredNumber,
  String? desiredComplement,
  String? desiredNeighborhood,
  String? desiredCity,
  String? desiredState,
  String? desiredSpecialty,
  String? desiredWorkerCnpj,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  final existing = await supabase
      .from('profiles')
      .select('id, role, name, email, phone, cep, address, number, complement, neighborhood, city, state, specialty, worker_cnpj, company_legal_name, company_trade_name, company_cnpj, company_responsible, company_email, company_address, company_number, company_complement, company_neighborhood, company_city, company_state, company_verified, woman_space_enabled, woman_space_visible, woman_space_receive_notifications')
      .eq('id', user.id)
      .maybeSingle()
      .timeout(const Duration(seconds: 3), onTimeout: () => null);

  final metadataRole = user.userMetadata?['role']?.toString();
  final metadataName = user.userMetadata?['name']?.toString();
  final metadataPhone = user.userMetadata?['phone']?.toString();
  final metadataCep = user.userMetadata?['cep']?.toString();
  final metadataAddress = user.userMetadata?['address']?.toString();
  final metadataNumber = user.userMetadata?['number']?.toString();
  final metadataComplement = user.userMetadata?['complement']?.toString();
  final metadataNeighborhood = user.userMetadata?['neighborhood']?.toString();
  final metadataCity = user.userMetadata?['city']?.toString();
  final metadataState = user.userMetadata?['state']?.toString();
  final metadataSpecialty = user.userMetadata?['specialty']?.toString();
  final metadataWorkerCnpj = user.userMetadata?['worker_cnpj']?.toString();
  final metadataCompanyLegalName = user.userMetadata?['company_legal_name']?.toString();
  final metadataCompanyTradeName = user.userMetadata?['company_trade_name']?.toString();
  final metadataCompanyCnpj = user.userMetadata?['company_cnpj']?.toString();
  final metadataCompanyResponsible = user.userMetadata?['company_responsible']?.toString();
  final metadataCompanyEmail = user.userMetadata?['company_email']?.toString();
  final metadataCompanyAddress = user.userMetadata?['company_address']?.toString();
  final metadataCompanyNumber = user.userMetadata?['company_number']?.toString();
  final metadataCompanyComplement = user.userMetadata?['company_complement']?.toString();
  final metadataCompanyNeighborhood = user.userMetadata?['company_neighborhood']?.toString();
  final metadataCompanyCity = user.userMetadata?['company_city']?.toString();
  final metadataCompanyState = user.userMetadata?['company_state']?.toString();
  final metadataCompanyVerified = user.userMetadata?['company_verified'] == true;
  final metadataWomanSpaceEnabled = boolFromDynamic(user.userMetadata?['woman_space_enabled']);
  final metadataWomanSpaceVisible = boolFromDynamic(user.userMetadata?['woman_space_visible']);
  final metadataWomanSpaceReceiveNotifications = boolFromDynamic(
    user.userMetadata?['woman_space_receive_notifications'],
    defaultValue: true,
  );

  final resolvedRole = desiredRole ?? metadataRole ?? roleClient;
  final resolvedName =
      desiredName ?? metadataName ?? user.email?.split('@').first ?? 'Usuário';
  final resolvedPhone = desiredPhone ?? metadataPhone;
  final resolvedCep = desiredCep ?? metadataCep;
  final resolvedAddress = desiredAddress ?? metadataAddress;
  final resolvedNumber = desiredNumber ?? metadataNumber;
  final resolvedComplement = desiredComplement ?? metadataComplement;
  final resolvedNeighborhood = desiredNeighborhood ?? metadataNeighborhood;
  final resolvedCity = desiredCity ?? metadataCity;
  final resolvedState = desiredState ?? metadataState;
  final resolvedSpecialty = desiredSpecialty ?? metadataSpecialty;
  final resolvedWorkerCnpj = desiredWorkerCnpj ?? metadataWorkerCnpj;
  final resolvedCompanyLegalName = metadataCompanyLegalName;
  final resolvedCompanyTradeName = metadataCompanyTradeName;
  final resolvedCompanyCnpj = metadataCompanyCnpj;
  final resolvedCompanyResponsible = metadataCompanyResponsible ?? resolvedName;
  final resolvedCompanyEmail = metadataCompanyEmail ?? user.email;
  final resolvedCompanyAddress = metadataCompanyAddress;
  final resolvedCompanyNumber = metadataCompanyNumber;
  final resolvedCompanyComplement = metadataCompanyComplement;
  final resolvedCompanyNeighborhood = metadataCompanyNeighborhood;
  final resolvedCompanyCity = metadataCompanyCity;
  final resolvedCompanyState = metadataCompanyState;
  final resolvedCompanyVerified = metadataCompanyVerified;
  final resolvedWomanSpaceEnabled = resolvedRole == roleClientCompany ? false : metadataWomanSpaceEnabled;
  final resolvedWomanSpaceVisible = resolvedWomanSpaceEnabled ? metadataWomanSpaceVisible : false;
  final resolvedWomanSpaceReceiveNotifications = resolvedRole == roleClientCompany ? false : metadataWomanSpaceReceiveNotifications;

  if (existing == null) {
    try {
      await supabase.from('profiles').insert({
        'id': user.id,
        'email': user.email,
        'name': resolvedName,
        'role': resolvedRole,
        'phone': resolvedPhone,
        'cep': resolvedCep,
        'address': resolvedAddress,
        'number': resolvedNumber,
        'complement': resolvedComplement,
        'neighborhood': resolvedNeighborhood,
        'city': resolvedCity,
        'state': resolvedState,
        'specialty': resolvedRole == roleWorker ? resolvedSpecialty : null,
        'worker_cnpj': resolvedRole == roleWorker ? resolvedWorkerCnpj : null,
        'company_legal_name': resolvedRole == roleClientCompany ? resolvedCompanyLegalName : null,
        'company_trade_name': resolvedRole == roleClientCompany ? resolvedCompanyTradeName : null,
        'company_cnpj': resolvedRole == roleClientCompany ? resolvedCompanyCnpj : null,
        'company_responsible': resolvedRole == roleClientCompany ? resolvedCompanyResponsible : null,
        'company_email': resolvedRole == roleClientCompany ? resolvedCompanyEmail : null,
        'company_address': resolvedRole == roleClientCompany ? resolvedCompanyAddress : null,
        'company_number': resolvedRole == roleClientCompany ? resolvedCompanyNumber : null,
        'company_complement': resolvedRole == roleClientCompany ? resolvedCompanyComplement : null,
        'company_neighborhood': resolvedRole == roleClientCompany ? resolvedCompanyNeighborhood : null,
        'company_city': resolvedRole == roleClientCompany ? resolvedCompanyCity : null,
        'company_state': resolvedRole == roleClientCompany ? resolvedCompanyState : null,
        'company_verified': resolvedRole == roleClientCompany ? resolvedCompanyVerified : false,
        'woman_space_enabled': resolvedWomanSpaceEnabled,
        'woman_space_visible': resolvedWomanSpaceVisible,
        'woman_space_receive_notifications': resolvedWomanSpaceReceiveNotifications,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        rethrow;
      }
    }
  } else {
    final updates = <String, dynamic>{};

    if (desiredRole != null && desiredRole.isNotEmpty) {
      updates['role'] = desiredRole;
    }
    final currentEmail = existing['email']?.toString();
    if ((currentEmail == null || currentEmail.isEmpty) && user.email != null) {
      updates['email'] = user.email;
    }
    if (resolvedRole == roleClientCompany) {
      updates['woman_space_enabled'] = false;
      updates['woman_space_visible'] = false;
      updates['woman_space_receive_notifications'] = false;
    } else {
      final currentWomanEnabled = boolFromDynamic(existing['woman_space_enabled']);
      final currentWomanVisible = boolFromDynamic(existing['woman_space_visible']);
      final currentWomanNotifications = existing['woman_space_receive_notifications'];

      if (metadataWomanSpaceEnabled && !currentWomanEnabled) {
        updates['woman_space_enabled'] = true;
        updates['woman_space_visible'] = metadataWomanSpaceVisible;
        updates['woman_space_receive_notifications'] = metadataWomanSpaceReceiveNotifications;
      } else if (metadataWomanSpaceEnabled && metadataWomanSpaceVisible && !currentWomanVisible) {
        updates['woman_space_visible'] = true;
      }

      if (currentWomanNotifications == null) {
        updates['woman_space_receive_notifications'] = metadataWomanSpaceReceiveNotifications;
      }
    }
    if (desiredName != null && desiredName.isNotEmpty) {
      updates['name'] = desiredName;
    }
    if (desiredPhone != null) {
      updates['phone'] = desiredPhone;
    }
    if (desiredCep != null) {
      updates['cep'] = desiredCep;
    }
    if (desiredAddress != null) updates['address'] = desiredAddress;
    if (desiredNumber != null) updates['number'] = desiredNumber;
    if (desiredComplement != null) updates['complement'] = desiredComplement;
    if (desiredNeighborhood != null) updates['neighborhood'] = desiredNeighborhood;
    if (desiredCity != null) updates['city'] = desiredCity;
    if (desiredState != null) updates['state'] = desiredState;
    if (desiredSpecialty != null || desiredRole == roleWorker) {
      updates['specialty'] = desiredSpecialty;
    }
    if (desiredWorkerCnpj != null || resolvedRole == roleWorker) {
      updates['worker_cnpj'] = resolvedRole == roleWorker ? resolvedWorkerCnpj : null;
    }
    if (resolvedRole == roleClientCompany) {
      updates['company_legal_name'] = resolvedCompanyLegalName;
      updates['company_trade_name'] = resolvedCompanyTradeName;
      updates['company_cnpj'] = resolvedCompanyCnpj;
      updates['company_responsible'] = resolvedCompanyResponsible;
      updates['company_email'] = resolvedCompanyEmail;
      updates['company_address'] = resolvedCompanyAddress;
      updates['company_number'] = resolvedCompanyNumber;
      updates['company_complement'] = resolvedCompanyComplement;
      updates['company_neighborhood'] = resolvedCompanyNeighborhood;
      updates['company_city'] = resolvedCompanyCity;
      updates['company_state'] = resolvedCompanyState;
      updates['company_verified'] = resolvedCompanyVerified;
    }

    if (updates.isNotEmpty) {
      await supabase.from('profiles').update(updates).eq('id', user.id);
    }
  }

  final wallet = await supabase
      .from('wallets')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle()
      .timeout(const Duration(seconds: 3), onTimeout: () => null);

  if (wallet == null) {
    try {
      await supabase.from('wallets').insert({
        'user_id': user.id,
        'balance': 0,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        rethrow;
      }
    }
  }
}

Future<String> getCurrentUserRole() async {
  final user = supabase.auth.currentUser;
  if (user == null) return roleClient;
  if (isPrivilegedAdminEmail(user.email)) return roleAdmin;

  try {
    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 3), onTimeout: () => null);

    final role = profile?['role']?.toString() ??
        user.userMetadata?['role']?.toString() ??
        roleClient;

    if (role == roleAdmin) return roleAdmin;
    if (role == roleWorker) return roleWorker;
    if (role == roleClientCompany) return roleClientCompany;
    return roleClient;
  } catch (_) {
    return user.userMetadata?['role']?.toString() ?? roleClient;
  }
}

Future<ProfileModel?> getCurrentProfile() async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final response = await supabase
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle()
      .timeout(const Duration(seconds: 3), onTimeout: () => null);

  if (response == null) return null;
  return ProfileModel.fromMap(Map<String, dynamic>.from(response));
}

Future<Map<String, dynamic>?> getPaymentByJobId(String jobId) async {
  final response = await supabase
      .from('payments')
      .select()
      .eq('job_id', jobId)
      .maybeSingle();

  if (response == null) return null;
  return Map<String, dynamic>.from(response);
}

Future<Map<String, dynamic>> _invokeAuthenticatedFunction(
  String functionName, {
  Map<String, dynamic>? body,
}) async {
  final session = supabase.auth.currentSession;
  if (session == null || session.accessToken.trim().isEmpty) {
    throw Exception('Sessão inválida. Saia da conta, entre novamente e tente de novo.');
  }

  final response = await supabase.functions.invoke(
    functionName,
    headers: {
      'Authorization': 'Bearer ${session.accessToken}',
      'apikey': supabaseAnonKey,
    },
    body: body ?? <String, dynamic>{},
  );

  if (response.data is Map) {
    return Map<String, dynamic>.from(response.data as Map);
  }
  return <String, dynamic>{};
}

Future<Map<String, dynamic>> syncReceivingConnectionStatus() async {
  final user = supabase.auth.currentUser;
  if (user == null) return <String, dynamic>{};
  return _invokeAuthenticatedFunction(
    'stripe-connect-status',
    body: {'user_id': user.id},
  );
}

Future<void> openReceivingAccount(BuildContext context) async {
  final uri = Uri.parse('https://connect.stripe.com/express_login');

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não consegui abrir sua conta de recebimento no navegador.'),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao abrir conta de recebimento: $e')),
    );
  }
}

Future<void> connectForReceiving(BuildContext context) async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    final data = await _invokeAuthenticatedFunction(
      'stripe-connect-start',
      body: {'user_id': user.id},
    );

    final rawUrl = data['auth_url'] ??
        data['url'] ??
        data['onboarding_url'] ??
        data['account_link_url'] ??
        data['connect_url'];
    final connectionUrl = rawUrl?.toString();

    if (connectionUrl == null || connectionUrl.trim().isEmpty) {
      throw Exception(
        data['message']?.toString() ??
            'Não foi possível iniciar a configuração para recebimentos.',
      );
    }

    final uri = Uri.tryParse(connectionUrl);
    if (uri == null) throw Exception('Link de configuração inválido.');

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conectar para receber'),
        content: const Text(
          'Não consegui abrir a configuração automaticamente. Toque em “Abrir configuração” ou copie o link para continuar no navegador seguro.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: connectionUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copiado.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar link'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir configuração'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4C61D),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao configurar recebimentos: $e')),
    );
  }
}

Future<void> syncJobPaymentStatus(String jobId) async {
  try {
    await _invokeAuthenticatedFunction(
      'stripe-sync-payment-status',
      body: {'job_id': jobId},
    );
  } catch (_) {
    // A sincronização é auxiliar. O webhook continua sendo a fonte principal.
  }
}

Future<void> createMarketplacePayment(BuildContext context, JobModel job) async {
  try {
    await syncJobPaymentStatus(job.id);

    final data = await _invokeAuthenticatedFunction(
      'stripe-create-payment',
      body: {'job_id': job.id},
    );

    final rawUrl = data['checkout_url'] ?? data['url'] ?? data['session_url'];
    final checkoutUrl = rawUrl?.toString();

    if (checkoutUrl == null || checkoutUrl.trim().isEmpty) {
      throw Exception(
        data['message']?.toString() ?? 'Não foi possível criar o pagamento.',
      );
    }

    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null) throw Exception('Link de pagamento inválido.');

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pagamento acompanhado'),
        content: const Text(
          'Não consegui abrir o pagamento automaticamente. Toque em “Abrir pagamento” ou copie o link para continuar no ambiente seguro de pagamento.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: checkoutUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link de pagamento copiado.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar link'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir pagamento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4C61D),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao iniciar pagamento: $e')),
    );
  }
}

Future<void> confirmConclusionAndRelease(BuildContext context, JobModel job) async {
  try {
    await syncJobPaymentStatus(job.id);

    final data = await _invokeAuthenticatedFunction(
      'stripe-release-payment',
      body: {'job_id': job.id},
    );

    if (data['success'] == false) {
      throw Exception(data['message']?.toString() ?? 'Não foi possível concluir o repasse.');
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Serviço concluído. O repasse ao prestador foi solicitado com segurança.'),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao concluir serviço: $e')),
    );
  }
}

Future<void> requestPaymentRefund(BuildContext context, JobModel job) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Solicitar reembolso'),
      content: const Text(
        'Confirme somente se você realmente deseja solicitar o reembolso deste pagamento. A solicitação será validada pelo servidor conforme o estado do serviço e do repasse.',
        style: TextStyle(height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Voltar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Solicitar reembolso'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final data = await _invokeAuthenticatedFunction(
      'stripe-refund-payment',
      body: {'job_id': job.id},
    );

    if (data['success'] == false) {
      throw Exception(data['message']?.toString() ?? 'O reembolso não pôde ser processado.');
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação de reembolso enviada.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao solicitar reembolso: $e')),
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  final Future<void> Function() onDone;

  const ResetPasswordPage({
    super.key,
    required this.onDone,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> updatePassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A nova senha precisa ter pelo menos 6 caracteres.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não conferem.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso. Entre novamente.')),
      );

      await widget.onDone();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao alterar senha: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao alterar senha: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EF),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/image.png',
                    height: 92,
                    errorBuilder: (_, __, ___) => const Icon(Icons.lock_reset, size: 86),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Criar nova senha',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Digite uma nova senha para acessar sua conta PegaeFazFree.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.35),
                  ),
                  const SizedBox(height: 22),
                  InputField(
                    controller: passwordController,
                    hint: 'Nova senha',
                    obscureText: obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputField(
                    controller: confirmPasswordController,
                    hint: 'Confirmar nova senha',
                    obscureText: obscureConfirmPassword,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                      icon: Icon(obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4C61D),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: loading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Salvar nova senha',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: loading ? null : widget.onDone,
                    child: const Text('Voltar para o login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final cepController = TextEditingController();
  final addressController = TextEditingController();
  final numberController = TextEditingController();
  final complementController = TextEditingController();
  final neighborhoodController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  bool searchingCep = false;
  final specialtyController = TextEditingController();
  final workerCnpjController = TextEditingController();
  final companyLegalNameController = TextEditingController();
  final companyTradeNameController = TextEditingController();
  final companyCnpjController = TextEditingController();
  final companyResponsibleController = TextEditingController();
  final companyAddressController = TextEditingController();
  final companyNumberController = TextEditingController();
  final companyComplementController = TextEditingController();
  final companyNeighborhoodController = TextEditingController();
  final companyCityController = TextEditingController();
  final companyStateController = TextEditingController();
  final professionalCouncilNumberController = TextEditingController();
  final professionalCouncilUfController = TextEditingController();
  final professionalRqeController = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  bool obscurePassword = true;
  String selectedRole = roleClient;

  @override
  void initState() {
    super.initState();
    stateController.text = supportedLaunchState;
    companyStateController.text = supportedLaunchState;
    workerCnpjController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    cepController.dispose();
    addressController.dispose();
    numberController.dispose();
    complementController.dispose();
    neighborhoodController.dispose();
    cityController.dispose();
    stateController.dispose();
    specialtyController.dispose();
    workerCnpjController.dispose();
    companyLegalNameController.dispose();
    companyTradeNameController.dispose();
    companyCnpjController.dispose();
    companyResponsibleController.dispose();
    companyAddressController.dispose();
    companyNumberController.dispose();
    companyComplementController.dispose();
    companyNeighborhoodController.dispose();
    companyCityController.dispose();
    companyStateController.dispose();
    professionalCouncilNumberController.dispose();
    professionalCouncilUfController.dispose();
    professionalRqeController.dispose();
    super.dispose();
  }


  bool womanSignupEnabled = false;
  bool womanSignupVisible = false;
  bool womanSignupReceiveNotifications = true;
  bool womanSignupPrefersFemaleService = false;
  bool womanSignupOffersFemaleOnlyService = false;
  bool womanSignupLookingForSupport = false;
  bool womanSignupAcceptsJobs = true;
  bool womanSignupTalentVisibleForCompanies = true;

  bool get selectedSpecialtyRequiresCouncil =>
      selectedRole == roleWorker && specialtyNeedsProfessionalCouncil(specialtyController.text.trim());

  String get selectedSpecialtyCouncilType =>
      requiredCouncilForText(specialtyController.text.trim());

  bool get selectedSpecialtyNeedsRqe =>
      selectedRole == roleWorker && needsRqeForText(specialtyController.text.trim());

  Widget professionalCouncilSignupFields() {
    if (selectedRole != roleWorker || isLogin || !selectedSpecialtyRequiresCouncil) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8DE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5C14A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Validação profissional obrigatória • $selectedSpecialtyCouncilType',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            selectedSpecialtyNeedsRqe
                ? 'Essa especialidade exige registro profissional e RQE.'
                : 'Essa especialidade exige registro profissional.',
            style: const TextStyle(height: 1.35, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          InputField(
            controller: professionalCouncilNumberController,
            hint: 'Número do $selectedSpecialtyCouncilType',
          ),
          const SizedBox(height: 12),
          InputField(
            controller: professionalCouncilUfController,
            hint: 'UF do $selectedSpecialtyCouncilType',
          ),
          if (selectedSpecialtyNeedsRqe) ...[
            const SizedBox(height: 12),
            InputField(
              controller: professionalRqeController,
              hint: 'RQE',
            ),
          ],
        ],
      ),
    );
  }

  Widget womanSpaceSignupSection() {
    // Espaço Mulher preservado no código/banco, mas oculto temporariamente para lançamento público.
    if (womanSpaceTemporarilyDisabled) return const SizedBox.shrink();
    if (isLogin || selectedRole == roleClientCompany) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Espaço Mulher', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Ative já no cadastro se quiser entrar nesse espaço opcional.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativar Espaço Mulher'),
            value: womanSignupEnabled,
            onChanged: (v) => setState(() => womanSignupEnabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar meu perfil no Espaço Mulher'),
            value: womanSignupEnabled && womanSignupVisible,
            onChanged: womanSignupEnabled ? (v) => setState(() => womanSignupVisible = v) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Receber notificações do Espaço Mulher'),
            value: womanSignupReceiveNotifications,
            onChanged: (v) => setState(() => womanSignupReceiveNotifications = v),
          ),
        ],
      ),
    );
  }


  Future<void> buscarEPreencherCep({bool empresa = false}) async {
    final controller = empresa ? cepController : cepController;
    final cep = controller.text.trim();
    if (onlyDigits(cep).length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um CEP com 8 números.')),
      );
      return;
    }

    setState(() => searchingCep = true);
    try {
      final data = await fetchAddressFromCep(cep);
      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não encontrei esse CEP. Preencha o endereço manualmente.')),
        );
        return;
      }

      final fetchedState = (data['state'] ?? '').toString().toUpperCase();
      final fetchedCity = normalizeLaunchCity((data['city'] ?? '').toString());

      if (fetchedState != supportedLaunchState) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por enquanto o PegaeFazFree está liberado apenas para Santa Catarina.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        if (selectedRole == roleClientCompany) {
          companyAddressController.text = data['address'] ?? '';
          companyNeighborhoodController.text = data['neighborhood'] ?? '';
          companyCityController.text = isScCity(fetchedCity) ? fetchedCity : '';
          companyStateController.text = supportedLaunchState;
        } else {
          addressController.text = data['address'] ?? '';
          neighborhoodController.text = data['neighborhood'] ?? '';
          cityController.text = isScCity(fetchedCity) ? fetchedCity : '';
          stateController.text = supportedLaunchState;
        }
      });
    } finally {
      if (mounted) setState(() => searchingCep = false);
    }
  }


  Widget stateDropdownField({
    required TextEditingController controller,
    String label = 'Estado',
  }) {
    return DropdownButtonFormField<String>(
      value: supportedLaunchState,
      decoration: fieldDecoration('$label (por enquanto apenas SC)'),
      items: brazilStatesLaunchOptions.map((state) {
        final uf = state.substring(0, 2);
        final locked = uf != supportedLaunchState;
        return DropdownMenuItem<String>(
          value: uf,
          enabled: !locked,
          child: Text(
            state,
            style: TextStyle(color: locked ? Colors.black38 : Colors.black87),
          ),
        );
      }).toList(),
      onChanged: (selected) {
        if (selected == null) return;
        if (selected != supportedLaunchState) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este estado será liberado em breve.')),
          );
          return;
        }
        setState(() {
          controller.text = supportedLaunchState;
        });
      },
    );
  }

  Widget scCityDropdownField({
    required TextEditingController controller,
    String label = 'Cidade/Município',
  }) {
    final cities = uniqueScCities();
    final current = isScCity(controller.text) ? normalizeLaunchCity(controller.text) : null;
    return DropdownButtonFormField<String>(
      value: current,
      isExpanded: true,
      decoration: fieldDecoration(label),
      items: cities
          .map(
            (city) => DropdownMenuItem<String>(
              value: city,
              child: Text(city, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (city) {
        if (city == null) return;
        setState(() {
          controller.text = city;
          stateController.text = supportedLaunchState;
          companyStateController.text = supportedLaunchState;
        });
      },
    );
  }

  Widget workerCnpjInfoSection() {
    if (selectedRole != roleWorker || isLogin) return const SizedBox.shrink();

    final hasCnpj = workerCnpjController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: hasCnpj ? const Color(0xFFFFF8DE) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasCnpj ? const Color(0xFFE5C14A) : Colors.black12,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: hasCnpj,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFF4C61D),
            child: Icon(Icons.business_center_outlined, color: Colors.black),
          ),
          title: const Text(
            'Entenda quando informar CNPJ',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            hasCnpj
                ? 'CNPJ informado. Confira a explicação abaixo.'
                : 'O CNPJ é opcional para prestadores.',
            style: const TextStyle(color: Colors.black54),
          ),
          children: const [
            Text(
              'O CNPJ não é obrigatório para começar como prestador no PegaeFazFree. '
              'Você pode deixar em branco e atualizar depois no perfil. '
              'Informe o CNPJ se você for MEI, autônomo formalizado ou tiver empresa aberta. '
              'Isso pode deixar seu perfil mais completo e passar mais confiança para clientes e empresas. '
              'O CNPJ não substitui registros obrigatórios de profissões regulamentadas, como CRM, COREN, CREA, OAB, CAU, CREFITO e outros quando forem necessários.',
              style: TextStyle(height: 1.45, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget addressFieldsForPersonalOrWorker() {
    if (isLogin || selectedRole == roleClientCompany) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InputField(
                controller: cepController,
                hint: 'CEP',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: searchingCep ? null : () => buscarEPreencherCep(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4C61D),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: searchingCep
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Buscar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InputField(controller: addressController, hint: 'Rua / endereço'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: InputField(controller: numberController, hint: 'Número')),
            const SizedBox(width: 12),
            Expanded(child: InputField(controller: complementController, hint: 'Complemento')),
          ],
        ),
        const SizedBox(height: 12),
        InputField(controller: neighborhoodController, hint: 'Bairro'),
        const SizedBox(height: 12),
        scCityDropdownField(controller: cityController),
        const SizedBox(height: 12),
        stateDropdownField(controller: stateController),
      ],
    );
  }

  Future<void> authenticate() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final cep = cepController.text.trim();
    final address = addressController.text.trim();
    final number = numberController.text.trim();
    final complement = complementController.text.trim();
    final neighborhood = neighborhoodController.text.trim();
    final city = normalizeLaunchCity(cityController.text.trim());
    final state = normalizedUf(stateController.text);
    final specialty = specialtyController.text.trim();
    final workerCnpj = workerCnpjController.text.trim();
    final companyLegalName = companyLegalNameController.text.trim();
    final companyTradeName = companyTradeNameController.text.trim();
    final companyCnpj = companyCnpjController.text.trim();
    final companyResponsible = companyResponsibleController.text.trim();
    final companyAddress = companyAddressController.text.trim();
    final companyNumber = companyNumberController.text.trim();
    final companyComplement = companyComplementController.text.trim();
    final companyNeighborhood = companyNeighborhoodController.text.trim();
    final companyCity = normalizeLaunchCity(companyCityController.text.trim());
    final companyState = normalizedUf(companyStateController.text);
    final professionalCouncilNumber = professionalCouncilNumberController.text.trim();
    final professionalCouncilUf = professionalCouncilUfController.text.trim().toUpperCase();
    final professionalRqe = professionalRqeController.text.trim();
    final councilRequired = selectedRole == roleWorker && specialtyNeedsProfessionalCouncil(specialty);
    final councilType = requiredCouncilForText(specialty);
    final rqeRequired = selectedRole == roleWorker && needsRqeForText(specialty);

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha email e senha.')),
      );
      return;
    }

    if (!isLogin && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome.')),
      );
      return;
    }

    if (!isLogin && selectedRole != roleClientCompany) {
      if (cep.isEmpty || address.isEmpty || number.isEmpty || neighborhood.isEmpty || city.isEmpty || state.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha CEP, endereço, número, bairro, cidade e UF.')),
        );
        return;
      }
      if (state != supportedLaunchState || !isScCity(city)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por enquanto selecione uma cidade de Santa Catarina.')),
        );
        return;
      }
    }

    if (!isLogin && selectedRole == roleWorker && specialty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a especialidade do prestador de serviços.'),
        ),
      );
      return;
    }

    if (!isLogin && selectedRole == roleWorker && councilRequired) {
      if (professionalCouncilNumber.isEmpty || professionalCouncilUf.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Para esta especialidade, informe $councilType e UF.')),
        );
        return;
      }
      if (rqeRequired && professionalRqe.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o RQE para esta especialidade médica.')),
        );
        return;
      }
    }

    if (!isLogin && selectedRole == roleClientCompany) {
      if (companyLegalName.isEmpty || companyTradeName.isEmpty || companyCnpj.isEmpty ||
          companyResponsible.isEmpty || companyAddress.isEmpty || companyNumber.isEmpty ||
          companyNeighborhood.isEmpty || companyCity.isEmpty || companyState.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha todos os dados obrigatórios da empresa.')),
        );
        return;
      }
      if (companyState.trim().toUpperCase() != supportedLaunchState || !isScCity(companyCity)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por enquanto a conta empresa está liberada apenas para cidades de Santa Catarina.')),
        );
        return;
      }
    }

    setState(() => loading = true);

    try {
      if (isLogin) {
await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

final confirmed = await isCurrentEmailConfirmed();
if (!confirmed) {
  await supabase.auth.signOut();
  throw Exception('Confirme seu email antes de entrar no PegaeFazFree.');
}

final bloqueado = await usuarioBloqueado();
if (bloqueado) {
  throw Exception('🚫 Usuário bloqueado');
}
        await ensureProfileExists();
      } else {
        final result = await supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: emailConfirmationRedirectUrl,
          data: {
            'name': name,
            'role': selectedRole,
            'phone': phone,
            'cep': cep,
            'address': selectedRole == roleClientCompany ? null : address,
            'number': selectedRole == roleClientCompany ? null : number,
            'complement': selectedRole == roleClientCompany ? null : complement,
            'neighborhood': selectedRole == roleClientCompany ? null : neighborhood,
            'city': selectedRole == roleClientCompany ? null : city,
            'state': selectedRole == roleClientCompany ? null : state,
            'specialty': selectedRole == roleWorker ? specialty : null,
            'worker_cnpj': selectedRole == roleWorker && workerCnpj.isNotEmpty ? workerCnpj : null,
            'professional_council_type': selectedRole == roleWorker && councilRequired ? councilType : null,
            'professional_council_number': selectedRole == roleWorker && councilRequired ? professionalCouncilNumber : null,
            'professional_council_uf': selectedRole == roleWorker && councilRequired ? professionalCouncilUf : null,
            'professional_rqe': selectedRole == roleWorker && rqeRequired ? professionalRqe : null,
            'company_legal_name': selectedRole == roleClientCompany ? companyLegalName : null,
            'company_trade_name': selectedRole == roleClientCompany ? companyTradeName : null,
            'company_cnpj': selectedRole == roleClientCompany ? companyCnpj : null,
            'company_responsible': selectedRole == roleClientCompany ? companyResponsible : null,
            'company_email': selectedRole == roleClientCompany ? email : null,
            'company_address': selectedRole == roleClientCompany ? companyAddress : null,
            'company_number': selectedRole == roleClientCompany ? companyNumber : null,
            'company_complement': selectedRole == roleClientCompany ? companyComplement : null,
            'company_neighborhood': selectedRole == roleClientCompany ? companyNeighborhood : null,
            'company_city': selectedRole == roleClientCompany ? companyCity : null,
            'company_state': selectedRole == roleClientCompany ? companyState : null,
            'company_verified': false,
            'woman_space_enabled': false,
            'woman_space_visible': false,
            'woman_space_receive_notifications': false,
          },
        );

        if (result.user != null) {
          await ensureProfileExists(
            desiredRole: selectedRole,
            desiredName: name,
            desiredPhone: phone,
            desiredCep: cep,
            desiredAddress: selectedRole == roleClientCompany ? null : address,
            desiredNumber: selectedRole == roleClientCompany ? null : number,
            desiredComplement: selectedRole == roleClientCompany ? null : complement,
            desiredNeighborhood: selectedRole == roleClientCompany ? null : neighborhood,
            desiredCity: selectedRole == roleClientCompany ? null : city,
            desiredState: selectedRole == roleClientCompany ? null : state,
            desiredSpecialty: selectedRole == roleWorker ? specialty : null,
            desiredWorkerCnpj: selectedRole == roleWorker && workerCnpj.isNotEmpty ? workerCnpj : null,
          );

          if (selectedRole == roleWorker) {
            try {
              await supabase.from('worker_resumes').upsert({
                'worker_id': result.user!.id,
                'full_name': name,
                'headline': specialty,
                'summary': '',
                'city': city,
                'state': state.isNotEmpty ? state : professionalCouncilUf,
                'phone': phone,
                'desired_categories': specialty,
                'worker_cnpj': workerCnpj.isNotEmpty ? workerCnpj : null,
                'experience': '',
                'education': '',
                'availability': '',
                'professional_council_type': councilRequired ? councilType : '',
                'professional_council_number': councilRequired ? professionalCouncilNumber : '',
                'professional_council_uf': councilRequired ? professionalCouncilUf : '',
                'professional_rqe': rqeRequired ? professionalRqe : '',
                'professional_validated': false,
                'validated_seal': '',
                'is_active': true,
              }, onConflict: 'worker_id');
            } catch (_) {}
          }
        }

        if (mounted) {
          await supabase.auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conta criada. Confira seu email para confirmar a conta antes de entrar.'),
            ),
          );
          setState(() {
            isLogin = true;
          });
        }
      }

      if (mounted) setState(() {});
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> sendPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite seu email para recuperar a senha.')),
      );
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: resetPasswordRedirectUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviamos o link de recuperação de senha para seu email.'),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao recuperar senha: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao recuperar senha: $e')),
      );
    }
  }

  Future<void> resendConfirmationEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite seu email para reenviar a confirmação.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: emailConfirmationRedirectUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enviamos um novo email de confirmação.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reenviar confirmação: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reenviar confirmação: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Widget roleChoice(String value, String label, IconData icon) {
    final selected = selectedRole == value;

    return InkWell(
      onTap: loading
          ? null
          : () {
              setState(() {
                selectedRole = value;
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4C61D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget accountUseCard({
    required String value,
    required String title,
    required String description,
    required String examples,
    required String buttonLabel,
    required IconData icon,
  }) {
    final selected = selectedRole == value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF4C7) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.black : Colors.black12, width: selected ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF4C61D),
                child: Icon(icon, color: Colors.black),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(height: 1.35, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Exemplos: $examples', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : () => setState(() => selectedRole = value),
              style: ElevatedButton.styleFrom(
                backgroundColor: selected ? Colors.black : const Color(0xFFF4C61D),
                foregroundColor: selected ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget specialtyChips() {
    if (selectedRole != roleWorker || isLogin) return const SizedBox.shrink();

    Widget chipForItem(String item, {bool highlighted = false}) {
      final selected = specialtyController.text.trim().toLowerCase() == item.toLowerCase();
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          specialtyController.text = item;
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF4C61D)
                : highlighted
                    ? const Color(0xFFFFF4C7)
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.black : (highlighted ? const Color(0xFFE5C14A) : Colors.black12),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            item,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    const highlightedRegulated = [
      'Médico geral',
      'Pediatra',
      'Cardiologista',
      'Enfermeiro',
      'Técnico de enfermagem',
      'Advogado',
      'Arquiteto',
      'Engenheiro',
      'Veterinário',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Sugestões rápidas',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...highlightedRegulated.map((item) => chipForItem(item, highlighted: true)),
            ...specialtySuggestions
                .where((item) => !highlightedRegulated.contains(item))
                .take(10)
                .map((item) => chipForItem(item)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              title: const Text(
                'Abrir especialidades por área',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'As opções estão organizadas pelas mesmas áreas disponíveis para quem contrata.',
                style: TextStyle(color: Colors.black54),
              ),
              children: workerSpecialtyGroups().entries.map((entry) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${entry.value.length} especialidade(s)',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: entry.value.map((item) {
                            final highlighted = highlightedRegulated.contains(item);
                            return chipForItem(item, highlighted: highlighted);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EF),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/image.png',
                    height: 100,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.handyman, size: 90),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'PegaeFazFree',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conectando clientes e prestadores de serviços locais',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  if (!isLogin) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Como você quer usar o PegaeFazFree?',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    accountUseCard(
                      value: roleClient,
                      title: 'Quero contratar um serviço',
                      description: 'Para pessoas que precisam de ajuda em casa ou no dia a dia.',
                      examples: 'diarista, eletricista, encanador, pintor, babá',
                      buttonLabel: 'Criar conta pessoal',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    accountUseCard(
                      value: roleWorker,
                      title: 'Quero trabalhar e oferecer meus serviços',
                      description: 'Para profissionais que querem atender clientes e ganhar dinheiro pela plataforma.',
                      examples: 'diarista, pedreiro, montador, cuidador, eletricista',
                      buttonLabel: 'Criar conta profissional',
                      icon: Icons.handyman_outlined,
                    ),
                    const SizedBox(height: 12),
                    accountUseCard(
                      value: roleClientCompany,
                      title: 'Quero contratar para minha empresa',
                      description: 'Para empresas, comércios e escritórios que precisam contratar serviços para o negócio.',
                      examples: 'manutenção, limpeza, reparos, apoio operacional, serviços recorrentes',
                      buttonLabel: 'Criar conta empresa',
                      icon: Icons.apartment_outlined,
                    ),
                    const SizedBox(height: 16),
                    InputField(
                      controller: nameController,
                      hint: selectedRole == roleClientCompany ? 'Nome do responsável' : 'Nome',
                    ),
                    const SizedBox(height: 12),
                    InputField(
                      controller: phoneController,
                      hint: 'Telefone',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    addressFieldsForPersonalOrWorker(),
                    if (selectedRole == roleWorker) ...[
                      const SizedBox(height: 12),
                      InputField(
                        controller: specialtyController,
                        hint: 'Especialidade principal',
                      ),
                      const SizedBox(height: 12),
                      InputField(
                        controller: workerCnpjController,
                        hint: 'CNPJ do prestador (opcional)',
                        keyboardType: TextInputType.number,
                      ),
                      workerCnpjInfoSection(),
                      specialtyChips(),
                      professionalCouncilSignupFields(),
                    ],
                    if (selectedRole == roleClientCompany) ...[
                      const SizedBox(height: 12),
                      InputField(controller: companyLegalNameController, hint: 'Razão social'),
                      const SizedBox(height: 12),
                      InputField(controller: companyTradeNameController, hint: 'Nome fantasia'),
                      const SizedBox(height: 12),
                      InputField(controller: companyCnpjController, hint: 'CNPJ'),
                      const SizedBox(height: 12),
                      InputField(controller: companyResponsibleController, hint: 'Responsável pela conta'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: InputField(controller: cepController, hint: 'CEP da empresa', keyboardType: TextInputType.number)),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: searchingCep ? null : () => buscarEPreencherCep(empresa: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4C61D),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: searchingCep
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : const Text('Buscar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InputField(controller: companyAddressController, hint: 'Endereço empresarial'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: InputField(controller: companyNumberController, hint: 'Número')),
                          const SizedBox(width: 12),
                          Expanded(child: InputField(controller: companyComplementController, hint: 'Complemento')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InputField(controller: companyNeighborhoodController, hint: 'Bairro'),
                      const SizedBox(height: 12),
                      scCityDropdownField(
                        controller: companyCityController,
                        label: 'Cidade/Município da empresa',
                      ),
                      const SizedBox(height: 12),
                      stateDropdownField(
                        controller: companyStateController,
                        label: 'Estado da empresa',
                      ),
                    ],
                    womanSpaceSignupSection(),
                    const SizedBox(height: 12),
                  ],
                  InputField(
                    controller: emailController,
                    hint: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  InputField(
                    controller: passwordController,
                    hint: 'Senha',
                    obscureText: obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                  if (isLogin) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: loading ? null : resendConfirmationEmail,
                          child: const Text('Reenviar confirmação'),
                        ),
                        TextButton(
                          onPressed: loading ? null : sendPasswordReset,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4C61D),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator()
                          : Text(
                              isLogin ? 'Entrar' : (selectedRole == roleClientCompany ? 'Criar conta empresa' : selectedRole == roleWorker ? 'Criar conta profissional' : 'Criar conta pessoal'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                    child: Text(
                      isLogin ? 'Criar conta' : 'Já tenho conta',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ao continuar, você concorda com os Termos de Uso, a Política de Privacidade e as orientações de Proteção do Usuário.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  String? role;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && loading) {
        setState(() {
          role = roleClient;
          loading = false;
        });
      }
    });
    loadRole();
  }

  Future<void> loadRole() async {
    try {
      final currentRole = await getCurrentUserRole();
      if (!mounted) return;
      setState(() {
        role = currentRole;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        role = roleClient;
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (role == roleAdmin || isPrivilegedAdminEmail(supabase.auth.currentUser?.email)) {
      return const AdminShell();
    }

    if (role == roleWorker) {
      return const WorkerShell();
    }

    if (role == roleClientCompany) {
      return const ClientCompanyShell();
    }

    return const ClientShell();
  }
}


class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  bool loading = true;
  ProfileModel? profile;
  List<JobModel> jobs = [];
  PffTrustMetrics trustMetrics = const PffTrustMetrics(
    ratingAverage: 0,
    ratingCount: 0,
    completedServices: 0,
    publishedServices: 0,
    contractedServices: 0,
    inProgressServices: 0,
    totalServices: 0,
    memberSince: 'Não informado',
  );
  List<double> monthlyDemand = const [0, 0, 0, 0, 0, 0];
  List<String> monthlyLabels = const ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun'];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      profile = await getCurrentProfile();

      final jobsResponse = await supabase
          .from('jobs')
          .select()
          .eq('client_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);
      jobs = (jobsResponse as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      trustMetrics = await loadUserTrustMetrics(user.id, role: roleClient);

      monthlyLabels = lastSixMonthLabels();
      final values = List<double>.filled(6, 0);
      for (final job in jobs) {
        final index = monthIndexInLastSix(job.createdAt);
        if (index >= 0) values[index] += 1;
      }
      monthlyDemand = values;
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openCreateJobPage() async {
    final result = await Navigator.push<CreateJobResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobPage(
          categories: HomePage.categories.where((e) => e != 'Todos').toList(),
        ),
      ),
    );

    if (result == null) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      final inserted = await supabase.from('jobs').insert({
        'title': result.title,
        'description': result.description,
        'category': result.category,
        'subservice': result.subservice,
        'location': result.location,
        'exact_address': result.exactAddress,
        'photo_url': result.photoUrl,
        'latitude': result.latitude,
        'longitude': result.longitude,
        'price': result.price,
        'client_id': user.id,
        'status': 'open',
      }).select('id').single();

      await notifyInterestedWorkersForJob(
        jobId: (inserted['id'] ?? '').toString(),
        category: result.category,
        title: result.title,
        location: result.location,
      );

      if (!mounted) return;
      await loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço publicado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao publicar serviço: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadData,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF7D91A), Color(0xFFE4A60B)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.name ?? 'Cliente', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text(
                      'Seu painel para acompanhar serviços contratados, conversas, avaliações e histórico de confiança.',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: openCreateJobPage,
                        icon: const Icon(Icons.add),
                        label: const Text('Publicar novo serviço'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    PffMetricCard(title: 'Serviços publicados', value: '${trustMetrics.publishedServices}', icon: Icons.assignment_outlined),
                    PffMetricCard(title: 'Serviços concluídos', value: '${trustMetrics.contractedServices}', icon: Icons.verified_outlined),
                    PffMetricCard(title: 'Em andamento', value: '${trustMetrics.inProgressServices}', icon: Icons.timelapse),
                    PffMetricCard(title: 'Avaliação', value: trustMetrics.ratingAverage.toStringAsFixed(1), icon: Icons.star_outline),
                    PffMetricCard(title: 'Avaliações', value: '${trustMetrics.ratingCount}', icon: Icons.rate_review_outlined),
                    PffMetricCard(title: 'Membro desde', value: trustMetrics.memberSince, icon: Icons.calendar_today_outlined),
                  ],
                ),
                const SizedBox(height: 12),
                PffDashboardBarChart(
                  title: 'Serviços publicados nos últimos 6 meses',
                  labels: monthlyLabels,
                  values: monthlyDemand,
                ),
                const SizedBox(height: 18),
                PffActionTile(
                  title: 'Feed de serviços',
                  subtitle: 'Veja os serviços que você publicou e as categorias do app.',
                  icon: Icons.home_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomePage())),
                ),
                const SizedBox(height: 10),
                PffActionTile(
                  title: 'Meus serviços',
                  subtitle: 'Acompanhe propostas, pagamento, conclusão e avaliações.',
                  icon: Icons.assignment_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyServicesPage())),
                ),
                const SizedBox(height: 10),
                PffActionTile(
                  title: 'Chats e negociações',
                  subtitle: 'Converse com prestadores e mantenha tudo dentro da plataforma.',
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListPage())),
                ),
                const SizedBox(height: 18),
                const Text('Últimos serviços', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (jobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Você ainda não publicou serviços.'),
                  )
                else
                  ...jobs.take(3).map((job) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RequestCard(job: job, onChanged: loadData, forceOwnerMode: true),
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}


class _ClientShellState extends State<ClientShell> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    ClientDashboardPage(),
    HomePage(),
    MyServicesPage(),
    ChatListPage(),
    ReviewsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.black45,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Painel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Serviços',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            label: 'Avaliações',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}


class ClientCompanyShell extends StatefulWidget {
  const ClientCompanyShell({super.key});

  @override
  State<ClientCompanyShell> createState() => _ClientCompanyShellState();
}

class _ClientCompanyShellState extends State<ClientCompanyShell> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    CompanyHomePage(),
    MyServicesPage(),
    CompanyResumeAccessPage(),
    ChatListPage(),
    ReviewsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.black45,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Empresa'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Serviços'),
          BottomNavigationBarItem(icon: Icon(Icons.badge_outlined), label: 'Talentos'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Avaliações'),
          BottomNavigationBarItem(icon: Icon(Icons.apartment_outlined), label: 'Perfil'),
        ],
      ),
    );
  }
}

class WorkerShell extends StatefulWidget {
  const WorkerShell({super.key});

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    WorkerHomePage(),
    WorkerJobsPage(),
    WorkerResumePage(),
    ChatListPage(),
    ReviewsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.black45,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Painel'),
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.badge_outlined), label: 'Currículo'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Avaliações'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    AdminDashboardPage(),
    HomePage(adminMode: true),
    WorkerJobsPage(adminMode: true),
    ChatListPage(adminMode: true),
    ReviewsPage(adminMode: true),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.black45,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            label: 'Painel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Cliente',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: 'Prestador',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            label: 'Avaliações',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool loading = true;
  int totalJobs = 0;
  int totalOpen = 0;
  int totalInProgress = 0;
  int totalDone = 0;
  int totalUsers = 0;
  int totalDeletedUsers = 0;
  int totalWorkers = 0;
  int totalProposals = 0;
  int totalAlerts = 0;
  int totalPendingReports = 0;
  double totalPaid = 0;
  double totalPlatformFee = 0;
  double totalWorkerNet = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final jobsResponse = await supabase.from('jobs').select('id,status');
      final profilesResponse = await supabase.from('profiles').select('id,role,name,email,is_blocked');

      final jobs = (jobsResponse as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final profiles = (profilesResponse as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      totalJobs = jobs.length;
      totalOpen = jobs.where((e) => (e['status'] ?? '') == 'open').length;
      totalInProgress = jobs.where((e) {
        final status = (e['status'] ?? '').toString();
        return status == 'proposal_sent' || status == 'in_progress';
      }).length;
      totalDone = jobs.where((e) => (e['status'] ?? '') == 'done').length;

      final activeProfiles =
          profiles.where((e) => !isDeletedProfileMap(e)).toList();
      final deletedProfiles =
          profiles.where((e) => isDeletedProfileMap(e)).toList();

      totalUsers = activeProfiles.length;
      totalDeletedUsers = deletedProfiles.length;
      totalWorkers = activeProfiles
          .where((e) => (e['role'] ?? '') == roleWorker)
          .length;

      try {
        final proposalsResponse = await supabase.from('proposals').select('id');
        totalProposals = (proposalsResponse as List).length;
      } catch (_) {
        totalProposals = 0;
      }

      try {
        final alertsResponse = await supabase.from('safety_events').select('id');
        totalAlerts = (alertsResponse as List).length;
      } catch (_) {
        totalAlerts = 0;
      }

      try {
        final reportsResponse = await supabase
            .from('user_reports')
            .select('id,status');
        totalPendingReports = (reportsResponse as List)
            .where((e) => (e['status'] ?? 'pending').toString() == 'pending')
            .length;
      } catch (_) {
        totalPendingReports = 0;
      }

      try {
        final paymentsResponse = await supabase
            .from('payments')
            .select(
              'amount,service_amount,status,platform_fee,platform_fee_amount,worker_net_amount',
            );

        final approvedPayments = (paymentsResponse as List)
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => (e['status'] ?? '').toString() == 'approved')
            .toList();

        double asDouble(dynamic value) {
          if (value is num) return value.toDouble();
          return double.tryParse(
                value?.toString().replaceAll(',', '.') ?? '',
              ) ??
              0;
        }

        totalPaid = approvedPayments.fold<double>(
          0,
          (sum, e) =>
              sum +
              asDouble(
                e['service_amount'] ?? e['amount'],
              ),
        );

        totalPlatformFee = approvedPayments.fold<double>(
          0,
          (sum, e) =>
              sum +
              asDouble(
                e['platform_fee_amount'] ?? e['platform_fee'],
              ),
        );

        totalWorkerNet = approvedPayments.fold<double>(
          0,
          (sum, e) => sum + asDouble(e['worker_net_amount']),
        );

        // Compatibilidade com registros antigos que ainda não tenham snapshot.
        if (totalWorkerNet <= 0 && totalPaid > 0) {
          totalWorkerNet = totalPaid - totalPlatformFee;
        }
      } catch (_) {
        totalPaid = 0;
        totalPlatformFee = 0;
        totalWorkerNet = 0;
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel ADM'),
        actions: [
          IconButton(onPressed: loadDashboard, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7D91A), Color(0xFFE4A60B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrador PegaeFazFree',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Conta com visão completa da operação.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _AdminStatCard(title: 'Total de serviços', value: '$totalJobs', icon: Icons.assignment_outlined),
                      _AdminStatCard(title: 'Serviços abertos', value: '$totalOpen', icon: Icons.mark_email_unread_outlined),
                      _AdminStatCard(title: 'Em andamento', value: '$totalInProgress', icon: Icons.timelapse),
                      _AdminStatCard(title: 'Concluídos', value: '$totalDone', icon: Icons.verified_outlined),
                      _AdminStatCard(title: 'Usuários ativos', value: '$totalUsers', icon: Icons.people_outline),
                      _AdminStatCard(title: 'Contas excluídas', value: '$totalDeletedUsers', icon: Icons.person_off_outlined),
                      _AdminStatCard(title: 'Prestadores', value: '$totalWorkers', icon: Icons.handyman_outlined),
                      _AdminStatCard(title: 'Propostas', value: '$totalProposals', icon: Icons.compare_arrows),
                      _AdminStatCard(title: 'Denúncias pendentes', value: '$totalPendingReports', icon: Icons.flag_outlined),
                      _AdminStatCard(title: 'Pagamentos aprovados', value: money(totalPaid), icon: Icons.account_balance_wallet_outlined),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PffDashboardBarChart(
                    title: 'Operação da plataforma',
                    labels: const ['Abertos', 'And.', 'Conc.', 'Usu.', 'Prest.', 'Prop.'],
                    values: [
                      totalOpen.toDouble(),
                      totalInProgress.toDouble(),
                      totalDone.toDouble(),
                      totalUsers.toDouble(),
                      totalWorkers.toDouble(),
                      totalProposals.toDouble(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PffDashboardBarChart(
                    title: 'Financeiro aprovado',
                    labels: const [
                      'Aprovado',
                      'Taxa da plataforma',
                      'Repasse',
                    ],
                    values: [
                      totalPaid,
                      totalPlatformFee,
                      totalWorkerNet,
                    ],
                    moneyValues: true,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _AdminActionCard(
                        title: 'Usuários',
                        subtitle: 'Perfis, papéis e busca',
                        icon: Icons.people_alt_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Propostas',
                        subtitle: 'Proposta e contra-proposta',
                        icon: Icons.compare_arrows,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProposalsPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Segurança IA',
                        subtitle: 'Alertas e moderação',
                        icon: Icons.shield_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSafetyPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Denúncias',
                        subtitle: 'Relatos enviados pelos usuários',
                        icon: Icons.flag_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Pagamentos',
                        subtitle: 'Pagamentos, confirmações e repasses',
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPaymentsPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Mensagem global',
                        subtitle: 'Banner rolante e promoções',
                        icon: Icons.campaign_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnnouncementsPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Currículos',
                        subtitle: 'Banco de talentos e acessos',
                        icon: Icons.badge_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminResumesPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Empresas',
                        subtitle: 'Clientes empresa e acessos',
                        icon: Icons.apartment_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCompaniesPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'CMS e banners',
                        subtitle: 'Catálogo, destaque e moderação',
                        icon: Icons.view_carousel_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCmsPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Prestadores',
                        subtitle: 'Onboarding, selo e portfólio',
                        icon: Icons.verified_user_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProviderVerificationPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Ordens e disputas',
                        subtitle: 'Fluxo operacional e arbitragem',
                        icon: Icons.rule_folder_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Comissões',
                        subtitle: 'Split, payout e repasses',
                        icon: Icons.pie_chart_outline,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCommissionsPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Localização',
                        subtitle: 'Match, raio e demanda',
                        icon: Icons.map_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLocationIntelligencePage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Reputação',
                        subtitle: 'Ranking e moderação de notas',
                        icon: Icons.workspace_premium_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReputationPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Booking e agenda',
                        subtitle: 'Check-in, agenda e aceitação',
                        icon: Icons.calendar_month_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBookingPage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Regras do motor',
                        subtitle: 'Modelo, urgência e preços',
                        icon: Icons.settings_suggest_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRulesEnginePage()));
                        },
                      ),
                      _AdminActionCard(
                        title: 'Spam e fraude',
                        subtitle: 'Pedidos falsos e bloqueios',
                        icon: Icons.report_gmailerrorred_outlined,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSpamPage()));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Relatórios executivos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        Text('Taxa de conclusão: ${totalJobs == 0 ? '0%' : '${((totalDone / totalJobs) * 100).toStringAsFixed(0)}%'}'),
                        const SizedBox(height: 6),
                        Text('Taxa em andamento: ${totalJobs == 0 ? '0%' : '${((totalInProgress / totalJobs) * 100).toStringAsFixed(0)}%'}'),
                        const SizedBox(height: 6),
                        Text('Prestadores por usuário: ${totalUsers == 0 ? '0' : (totalWorkers / totalUsers).toStringAsFixed(2)}'),
                        const SizedBox(height: 6),
                        Text('Alertas de segurança: $totalAlerts'),
                        const SizedBox(height: 6),
                        Text('Contas excluídas preservadas no histórico: $totalDeletedUsers'),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      'Alertas ativos de segurança: $totalAlerts\n\n'
                      'O que esta conta ADM ja consegue fazer\n'
                      '- visualizar servicos como cliente\n'
                      '- visualizar servicos como prestador\n'
                      '- abrir chats\n'
                      '- alterar status\n'
                      '- excluir servicos\n'
                      '- acompanhar avaliacoes\n'
                      '- analisar alertas de seguranca\n'
                      '- acompanhar propostas e contra-propostas\n'
                      '- enviar banner global para todo o aplicativo\n'
                      '- acompanhar relatórios executivos do painel',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool loading = true;
  bool deletingUser = false;
  List<Map<String, dynamic>> profiles = [];
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProfiles();
    searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadProfiles() async {
    if (mounted) setState(() => loading = true);
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .order('name', ascending: true);

      profiles = (response as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar usuários: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateRole(String id, String role) async {
    try {
      await supabase.from('profiles').update({'role': role}).eq('id', id);
      await loadProfiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao alterar papel: $e')),
      );
    }
  }

  Future<void> toggleBlocked(Map<String, dynamic> profile) async {
    final id = (profile['id'] ?? '').toString();
    if (id.isEmpty) return;

    final isBlocked = profile['is_blocked'] == true;

    try {
      await supabase
          .from('profiles')
          .update({'is_blocked': !isBlocked})
          .eq('id', id);

      await loadProfiles();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBlocked
                ? 'Usuário desbloqueado com sucesso.'
                : 'Usuário bloqueado com sucesso.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar bloqueio: $e')),
      );
    }
  }

  Future<void> deleteUserAsAdmin(Map<String, dynamic> profile) async {
    if (deletingUser) return;

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final targetId = (profile['id'] ?? '').toString().trim();
    final targetRole = (profile['role'] ?? '').toString().trim().toLowerCase();
    final targetEmail = (profile['email'] ?? '').toString().trim().toLowerCase();
    final targetName = displayProfileNameFromMap(
      profile,
      fallback: 'usuário selecionado',
    );

    if (targetId.isEmpty) return;

    if (targetId == currentUser.id ||
        targetRole == roleAdmin ||
        isPrivilegedAdminEmail(targetEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A conta administrativa principal não pode ser excluída por esta tela.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir conta do usuário?'),
        content: Text(
          'Você está prestes a excluir a conta de "$targetName".\n\n'
          'A exclusão é uma ação administrativa sensível. '
          'Serviços, pagamentos ou registros que precisem ser preservados '
          'podem impedir a exclusão ou permanecer anonimizados para histórico e segurança.',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Excluir conta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => deletingUser = true);

    try {
      final data = await _invokeAuthenticatedFunction(
        'admin-delete-account',
        body: {
          'target_user_id': targetId,
          'confirmation': 'EXCLUIR',
        },
      );

      final ok = data['success'] == true || data['ok'] == true;
      if (!ok) {
        throw Exception(
          data['message']?.toString() ??
              'Não foi possível excluir esta conta.',
        );
      }

      await loadProfiles();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conta de "$targetName" excluída com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exclusão administrativa indisponível ou não concluída: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => deletingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = searchController.text.trim().toLowerCase();
    final activeProfiles =
        profiles.where((profile) => !isDeletedProfileMap(profile)).toList();
    final deletedProfiles =
        profiles.where((profile) => isDeletedProfileMap(profile)).toList();

    final filtered = profiles.where((profile) {
      final displayName =
          displayProfileNameFromMap(profile, fallback: '').toLowerCase();
      final name = (profile['name'] ?? '').toString().toLowerCase();
      final email = (profile['email'] ?? '').toString().toLowerCase();
      final id = (profile['id'] ?? '').toString().toLowerCase();
      final company =
          (profile['company_trade_name'] ?? '').toString().toLowerCase();

      return q.isEmpty ||
          displayName.contains(q) ||
          name.contains(q) ||
          email.contains(q) ||
          id.contains(q) ||
          company.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários e papéis'),
        actions: [
          IconButton(
            onPressed: loading ? null : loadProfiles,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadProfiles,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFF4C61D),
                          foregroundColor: Colors.black,
                          child: Icon(Icons.people_alt_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${activeProfiles.length} usuários ativos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                q.isEmpty
                                    ? '${deletedProfiles.length} conta(s) excluída(s) preservada(s) no histórico.'
                                    : '${filtered.length} resultado(s) nesta busca.',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: fieldDecoration('Buscar nome, e-mail ou id'),
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Nenhum usuário encontrado.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...filtered.map((profile) {
                      final id = (profile['id'] ?? '').toString();
                      final role =
                          (profile['role'] ?? roleClient).toString();
                      final isBlocked = profile['is_blocked'] == true;
                      final isDeleted = isDeletedProfileMap(profile);
                      final email = (profile['email'] ?? '').toString().trim();
                      final name = displayProfileNameFromMap(
                        profile,
                        fallback: 'Nome não informado',
                      );
                      final isProtectedAdmin = id ==
                              (supabase.auth.currentUser?.id ?? '') ||
                          role == roleAdmin ||
                          isPrivilegedAdminEmail(email);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDeleted
                                ? Colors.black26
                                : isBlocked
                                    ? Colors.redAccent.withValues(alpha: 0.28)
                                    : const Color(0xFFE8E0D5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFF4C61D),
                                  foregroundColor: Colors.black,
                                  child: Text(
                                    displayProfileInitial(name),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                      if (email.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        id,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.black45,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 145,
                                  child: DropdownButtonFormField<String>(
                                    value: role,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Papel',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: roleClient,
                                        child: Text('Cliente'),
                                      ),
                                      DropdownMenuItem(
                                        value: roleClientCompany,
                                        child: Text('Empresa'),
                                      ),
                                      DropdownMenuItem(
                                        value: roleWorker,
                                        child: Text('Prestador'),
                                      ),
                                      DropdownMenuItem(
                                        value: roleAdmin,
                                        child: Text('Admin'),
                                      ),
                                    ],
                                    onChanged: isProtectedAdmin || isDeleted
                                        ? null
                                        : (value) {
                                            if (value == null) return;
                                            updateRole(id, value);
                                          },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (isDeleted)
                                  const Chip(
                                    avatar: Icon(
                                      Icons.person_off_outlined,
                                      size: 16,
                                    ),
                                    label: Text('Conta excluída'),
                                  )
                                else ...[
                                  OutlinedButton.icon(
                                    onPressed: isProtectedAdmin
                                        ? null
                                        : () => toggleBlocked(profile),
                                    icon: Icon(
                                      isBlocked
                                          ? Icons.lock_open_outlined
                                          : Icons.block_outlined,
                                    ),
                                    label: Text(
                                      isBlocked ? 'Desbloquear' : 'Bloquear',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isBlocked
                                          ? Colors.green.shade700
                                          : Colors.redAccent,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: isProtectedAdmin || deletingUser
                                        ? null
                                        : () => deleteUserAsAdmin(profile),
                                    icon: const Icon(
                                      Icons.delete_forever_outlined,
                                    ),
                                    label: const Text('Excluir conta'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade800,
                                    ),
                                  ),
                                  if (isBlocked)
                                    const Chip(
                                      avatar: Icon(
                                        Icons.lock_outline,
                                        size: 16,
                                      ),
                                      label: Text('Bloqueado'),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class AdminProposalsPage extends StatefulWidget {
  const AdminProposalsPage({super.key});

  @override
  State<AdminProposalsPage> createState() => _AdminProposalsPageState();
}

class _AdminProposalsPageState extends State<AdminProposalsPage> {
  bool loading = true;
  List<ProposalModel> proposals = [];
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    loadProposals();
  }

  Future<void> loadProposals() async {
    setState(() => loading = true);
    try {
      final response = await supabase.from('proposals').select().order('created_at', ascending: false);
      proposals = (response as List)
          .map((e) => ProposalModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      proposals = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateProposalStatus(ProposalModel proposal, String status) async {
    try {
      if (status == 'accepted') {
        await supabase.from('proposals').update({'status': 'accepted'}).eq('id', proposal.id);
        await supabase
            .from('proposals')
            .update({'status': 'rejected'})
            .eq('job_id', proposal.jobId)
            .neq('id', proposal.id);
        await supabase.from('jobs').update({
          'worker_id': proposal.workerId,
          'price': proposal.amount,
          'status': 'proposal_sent',
        }).eq('id', proposal.jobId);

        await createNotificationForUser(
          userId: proposal.workerId,
          title: 'Proposta aceita',
          body: 'Sua proposta de ${money(proposal.amount)} foi aceita.',
          referenceType: 'proposal',
          referenceId: proposal.jobId,
        );
      } else {
        await supabase.from('proposals').update({'status': status}).eq('id', proposal.id);
      }
      await loadProposals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar proposta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = proposals.where((proposal) {
      if (filter == 'all') return true;
      return proposal.status == filter;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Propostas e contra-propostas')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : proposals.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'Nenhuma proposta encontrada.\n'
                      'Se a tabela proposals ainda nao existir, crie depois no Supabase.',
                    ),
                ))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['all', 'pending', 'accepted', 'rejected']
                          .map(
                            (value) => ChoiceChip(
                              label: Text(value == 'all' ? 'Todas' : value),
                              selected: filter == value,
                              onSelected: (_) {
                                setState(() {
                                  filter = value;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    ...filtered.map((proposal) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            proposal.isCounter ? 'Contra-proposta' : 'Proposta',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text('Valor: ${money(proposal.amount)}'),
                          Text('Status: ${proposal.status}'),
                          if (proposal.message.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(proposal.message),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => updateProposalStatus(proposal, 'accepted'),
                                child: const Text('Aceitar'),
                              ),
                              OutlinedButton(
                                onPressed: () => updateProposalStatus(proposal, 'rejected'),
                                child: const Text('Recusar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
    );
  }
}

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool loading = true;
  String selectedStatus = 'all';
  String? errorText;
  List<Map<String, dynamic>> reports = [];
  final Map<String, Map<String, dynamic>> profilesById = {};

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorText = null;
      });
    }

    try {
      final response = await supabase
          .from('user_reports')
          .select()
          .order('created_at', ascending: false);

      final loaded = (response as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final ids = <String>{};
      for (final report in loaded) {
        final reporterId = (report['reporter_id'] ?? '').toString().trim();
        final reportedId = (report['reported_user_id'] ?? '').toString().trim();
        if (reporterId.isNotEmpty) ids.add(reporterId);
        if (reportedId.isNotEmpty) ids.add(reportedId);
      }

      final loadedProfiles = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final profilesResponse = await supabase
            .from('profiles')
            .select(
              'id,email,name,role,company_trade_name,company_legal_name,company_responsible,is_blocked',
            )
            .inFilter('id', ids.toList());

        for (final item in (profilesResponse as List)) {
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] ?? '').toString();
          if (id.isNotEmpty) loadedProfiles[id] = map;
        }
      }

      if (!mounted) return;
      setState(() {
        reports = loaded;
        profilesById
          ..clear()
          ..addAll(loadedProfiles);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        reports = [];
        profilesById.clear();
        errorText = e.toString();
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String profileName(String userId, {String fallback = 'Usuário'}) {
    return displayProfileNameFromMap(
      profilesById[userId],
      fallback: fallback,
    );
  }

  Future<void> updateReportStatus(
    Map<String, dynamic> report,
    String status,
  ) async {
    final reportId = (report['id'] ?? '').toString().trim();
    final adminId = supabase.auth.currentUser?.id;
    if (reportId.isEmpty || adminId == null) return;

    try {
      await supabase.from('user_reports').update({
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': adminId,
      }).eq('id', reportId);

      await loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Denúncia marcada como ${userReportStatusLabel(status).toLowerCase()}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar denúncia: $e')),
      );
    }
  }

  Future<void> blockReportedUser(Map<String, dynamic> report) async {
    final userId = (report['reported_user_id'] ?? '').toString().trim();
    if (userId.isEmpty) return;

    final name = profileName(userId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bloquear conta'),
        content: Text(
          'Deseja bloquear a conta de $name? O bloqueio não exclui a conta e pode ser revertido pelo painel de usuários.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('profiles')
          .update({'is_blocked': true})
          .eq('id', userId);

      if ((report['status'] ?? 'pending').toString() == 'pending') {
        await updateReportStatus(report, 'reviewing');
      } else {
        await loadReports();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta bloqueada pelo administrador.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao bloquear conta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = selectedStatus == 'all'
        ? reports
        : reports
            .where(
              (report) =>
                  (report['status'] ?? 'pending').toString() == selectedStatus,
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Denúncias de usuários'),
        actions: [
          IconButton(
            onPressed: loadReports,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadReports,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Central de denúncias',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'As denúncias não bloqueiam contas automaticamente. Analise o contexto antes de tomar uma ação.',
                          style: TextStyle(color: Colors.black54, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: fieldDecoration('Filtrar por status'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Todas')),
                            DropdownMenuItem(value: 'pending', child: Text('Pendentes')),
                            DropdownMenuItem(value: 'reviewing', child: Text('Em análise')),
                            DropdownMenuItem(value: 'resolved', child: Text('Resolvidas')),
                            DropdownMenuItem(value: 'dismissed', child: Text('Descartadas')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedStatus = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (errorText != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Não foi possível carregar as denúncias. Verifique se a tabela user_reports foi criada no Supabase.\n\n$errorText',
                        style: const TextStyle(height: 1.4),
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Nenhuma denúncia neste filtro.'),
                      ),
                    )
                  else
                    ...filtered.map((report) {
                      final reporterId =
                          (report['reporter_id'] ?? '').toString();
                      final reportedId =
                          (report['reported_user_id'] ?? '').toString();
                      final status =
                          (report['status'] ?? 'pending').toString();
                      final reason = (report['reason'] ?? '').toString();
                      final details = (report['details'] ?? '').toString().trim();
                      final source = (report['source'] ?? '').toString();
                      final jobId = (report['job_id'] ?? '').toString().trim();
                      final messageId =
                          (report['message_id'] ?? '').toString().trim();
                      final createdAt = DateTime.tryParse(
                        (report['created_at'] ?? '').toString(),
                      )?.toLocal();
                      final reportedProfile = profilesById[reportedId];
                      final isBlocked = reportedProfile?['is_blocked'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: userReportStatusColor(status).withOpacity(0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: userReportStatusColor(status)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    userReportStatusLabel(status),
                                    style: TextStyle(
                                      color: userReportStatusColor(status),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Denunciado: ${profileName(reportedId, fallback: 'Usuário não encontrado')}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Denunciante: ${profileName(reporterId, fallback: 'Usuário não encontrado')}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Origem: $source${createdAt == null ? '' : ' • ${formatDate(createdAt)} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (jobId.isNotEmpty)
                              Text(
                                'Serviço: $jobId',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            if (messageId.isNotEmpty)
                              Text(
                                'Mensagem: $messageId',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F5F1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(details),
                              ),
                            ],
                            if (isBlocked) ...[
                              const SizedBox(height: 10),
                              const Chip(
                                avatar: Icon(Icons.block, size: 17),
                                label: Text('Conta bloqueada'),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: reportedId.isEmpty
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PublicProfilePage(
                                                profileId: reportedId,
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.person_outline),
                                  label: const Text('Ver perfil'),
                                ),
                                if (status == 'pending')
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        updateReportStatus(report, 'reviewing'),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('Em análise'),
                                  ),
                                if (status != 'resolved')
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        updateReportStatus(report, 'resolved'),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Resolver'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                if (status != 'dismissed')
                                  TextButton.icon(
                                    onPressed: () =>
                                        updateReportStatus(report, 'dismissed'),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Descartar'),
                                  ),
                                if (!isBlocked)
                                  TextButton.icon(
                                    onPressed: () => blockReportedUser(report),
                                    icon: const Icon(Icons.block),
                                    label: const Text('Bloquear conta'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class AdminSafetyPage extends StatefulWidget {
  const AdminSafetyPage({super.key});

  @override
  State<AdminSafetyPage> createState() => _AdminSafetyPageState();
}

class _AdminSafetyPageState extends State<AdminSafetyPage> {
  bool loading = true;
  List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() => loading = true);
    try {
      final response = await supabase.from('safety_events').select().order('created_at', ascending: false);
      events = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      events = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Segurança IA embutida')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhum alerta ainda.\n'
                      'A IA embutida ja esta ativa no app para mensagens e propostas.',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final event = events[index];
                    final blocked = event['blocked'] == true;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: blocked ? Colors.redAccent : Colors.orangeAccent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            blocked ? 'Bloqueado' : 'Sinalizado',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: blocked ? Colors.red : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text((event['reason'] ?? '').toString()),
                          const SizedBox(height: 8),
                          Text((event['content'] ?? '').toString()),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool loading = true;
  List<Map<String, dynamic>> payments = [];

  @override
  void initState() {
    super.initState();
    loadPayments();
  }

  Future<void> loadPayments() async {
    setState(() => loading = true);
    try {
      final response = await supabase.from('payments').select().order('created_at', ascending: false);
      payments = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      payments = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final approved = payments.where((e) => (e['status'] ?? '').toString() == 'approved');
    final totalApproved = approved.fold<double>(0, (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble());
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamentos e repasses')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Total aprovado: ${money(totalApproved)}\n'
                    'Registros: ${payments.length}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                if (payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Nenhum pagamento encontrado.')),
                  )
                else
                  ...payments.map((payment) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Job: ${(payment['job_id'] ?? '').toString()}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('Status: ${(payment['status'] ?? '').toString()}'),
                        Text('Valor: ${money(((payment['amount'] ?? 0) as num).toDouble())}'),
                      ],
                    ),
                  )),
              ],
            ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool adminMode;
  final bool workerMode;
  final bool companyMode;

  const HomePage({
    super.key,
    this.adminMode = false,
    this.workerMode = false,
    this.companyMode = false,
  });

  static const List<String> categories = appCategories;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController categoriesScrollController = ScrollController();

  String selectedCategory = 'Todos';
  List<JobModel> jobs = [];
  bool loading = true;
  String? errorText;
  bool showLeftArrow = false;

  @override
  void initState() {
    super.initState();
    bootstrap();

    searchController.addListener(() {
      if (mounted) setState(() {});
    });

    categoriesScrollController.addListener(() {
      if (!mounted) return;

      final shouldShowLeft = categoriesScrollController.hasClients &&
          categoriesScrollController.offset > 10;

      if (showLeftArrow != shouldShowLeft) {
        setState(() {
          showLeftArrow = shouldShowLeft;
        });
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    categoriesScrollController.dispose();
    super.dispose();
  }

  Future<void> bootstrap() async {
    try {
      setState(() {
        loading = true;
        errorText = null;
      });
      await ensureProfileExists();
      await loadJobs();
    } catch (e) {
      setState(() {
        loading = false;
        errorText = 'Erro ao iniciar: $e';
      });
    }
  }

  Future<void> loadJobs() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            loading = false;
            errorText = 'Usuário não autenticado.';
          });
        }
        return;
      }

      dynamic response;

      if (widget.adminMode) {
        response = await supabase
            .from('jobs')
            .select()
            .order('created_at', ascending: false);
      } else if (widget.workerMode) {
        response = await supabase
            .from('jobs')
            .select()
            .neq('client_id', user.id)
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('jobs')
            .select()
            .eq('client_id', user.id)
            .order('created_at', ascending: false);
      }

      final list = (response as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      await refreshAllVisiblePayments(list);

      if (!mounted) return;
      setState(() {
        jobs = list;
        loading = false;
        errorText = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorText = 'Erro ao carregar serviços: $e';
      });
    }
  }

  List<JobModel> get filteredJobs {
    final q = searchController.text.trim().toLowerCase();

    return jobs.where((job) {
      final categoryOk =
          selectedCategory == 'Todos' || job.category == selectedCategory;

      final searchOk = q.isEmpty ||
          job.title.toLowerCase().contains(q) ||
          job.description.toLowerCase().contains(q) ||
          job.publicLocationLabel.toLowerCase().contains(q) ||
          job.category.toLowerCase().contains(q) ||
          job.subservice.toLowerCase().contains(q);

      return categoryOk && searchOk;
    }).toList();
  }

  List<JobModel> get popularJobs => jobs.take(4).toList();

  Future<void> openCreateJobPage() async {
    final result = await Navigator.push<CreateJobResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobPage(
          categories: HomePage.categories.where((e) => e != 'Todos').toList(),
        ),
      ),
    );

    if (result == null) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      final inserted = await supabase.from('jobs').insert({
        'title': result.title,
        'description': result.description,
        'category': result.category,
        'subservice': result.subservice,
        'location': result.location,
        'exact_address': result.exactAddress,
        'photo_url': result.photoUrl,
        'latitude': result.latitude,
        'longitude': result.longitude,
        'price': result.price,
        'client_id': user.id,
        'status': 'open',
      }).select('id').single();
      await notifyInterestedWorkersForJob(
        jobId: (inserted['id'] ?? '').toString(),
        category: result.category,
        title: result.title,
        location: result.location,
      );

      if (!mounted) return;

      await loadJobs();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço publicado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao publicar serviço: $e')),
      );
    }
  }

  void openAllServicesPage({String fixedCategory = 'Todos'}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllServicesPage(
          fixedCategory: fixedCategory,
          onChanged: loadJobs,
          adminMode: widget.adminMode,
          workerMode: widget.workerMode,
          companyMode: widget.companyMode,
        ),
      ),
    );
  }

  void openJobDetails(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsPage(
          job: job,
          onChanged: loadJobs,
          adminMode: widget.adminMode,
        ),
      ),
    );
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.workerMode
          ? null
          : FloatingActionButton.extended(
              onPressed: openCreateJobPage,
              backgroundColor: const Color(0xFFF4C61D),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: Text(
                widget.adminMode ? 'Publicar ADM' : 'Publicar',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadJobs,
          child: ListView(
            children: [
              buildHeader(),
              const SizedBox(height: 18),
              buildPopularSection(),
              const SizedBox(height: 18),
              buildFeedSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7D91A), Color(0xFFE4A60B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/image.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.handyman,
                    size: 34,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.adminMode
                      ? 'PegaeFazFree ADM'
                      : widget.workerMode
                          ? 'PegaeFazFree Prestador'
                          : widget.companyMode
                              ? 'PegaeFazFree Empresa'
                              : 'PegaeFazFree',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                onPressed: logout,
                icon: const Icon(Icons.logout, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.adminMode
                ? 'Visão administrativa dos serviços da plataforma.'
                : widget.workerMode
                    ? 'Encontre oportunidades e serviços compatíveis com o seu trabalho.'
                    : widget.companyMode
                        ? 'Gerencie demandas da sua empresa e encontre profissionais com rapidez.'
                        : 'Encontre o profissional ideal para o que você precisa.',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.adminMode
                ? 'Pesquise, filtre e acompanhe tudo como administrador.'
                : widget.workerMode
                    ? 'Pesquise, filtre e acompanhe oportunidades como prestador.'
                    : widget.companyMode
                        ? 'Pesquise, filtre e acompanhe serviços da sua empresa.'
                        : 'Pesquise, filtre por categoria e publique serviços com rapidez.',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          const ActiveAnnouncementBanner(),
          const SizedBox(height: 12),
          Container(
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: widget.workerMode ? 'Buscar oportunidades...' : 'Buscar serviços...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close, color: Colors.black54),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 112,
            child: Stack(
              children: [
                ListView.separated(
                  controller: categoriesScrollController,
                  padding: const EdgeInsets.only(left: 54, right: 54),
                  scrollDirection: Axis.horizontal,
                  itemCount: HomePage.categories.length - 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final category = HomePage.categories[index + 1];
                    final selected = selectedCategory == category;

                    return CategoryCard(
                      category: category,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          selectedCategory = selected ? 'Todos' : category;
                        });
                      },
                    );
                  },
                ),
                if (showLeftArrow)
                  Positioned(
                    left: 0,
                    top: 18,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        if (!categoriesScrollController.hasClients) return;

                        final nextOffset =
                            categoriesScrollController.offset - 220;
                        final minOffset = 0.0;

                        await categoriesScrollController.animateTo(
                          nextOffset < minOffset ? minOffset : nextOffset,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              const Color(0xFFF7D91A).withOpacity(0.0),
                              const Color(0xFFE4A60B).withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  top: 18,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      if (!categoriesScrollController.hasClients) return;

                      final nextOffset =
                          categoriesScrollController.offset + 220;
                      final maxOffset =
                          categoriesScrollController.position.maxScrollExtent;

                      await categoriesScrollController.animateTo(
                        nextOffset > maxOffset ? maxOffset : nextOffset,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFFF7D91A).withOpacity(0.0),
                            const Color(0xFFE4A60B).withOpacity(0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPopularSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.adminMode
                          ? 'Serviços em Destaque'
                          : widget.workerMode
                              ? 'Oportunidades em Destaque'
                              : 'Serviços Populares',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.adminMode
                          ? 'Visão geral administrativa'
                          : widget.workerMode
                              ? 'Vagas e serviços mais recentes'
                              : 'Categorias e oportunidades em destaque',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => openAllServicesPage(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE3DF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Ver todos',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: popularJobs.isEmpty
                ? Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      'Nenhum serviço ainda.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: popularJobs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final job = popularJobs[index];
                      return PopularServiceCard(
                        job: job,
                        onTap: () => openJobDetails(job),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Explorar por categoria',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HomePage.categories
                .where((e) => e != 'Todos')
                .map(
                  (category) => InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => openAllServicesPage(fixedCategory: category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(categoryIcon(category), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget buildFeedSection() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorText != null) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            errorText!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
            ),
          ),
        ),
      );
    }

    final list = filteredJobs;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedCategory == 'Todos'
                ? (widget.adminMode
                    ? 'Todos os serviços da plataforma'
                    : widget.workerMode
                        ? 'Oportunidades disponíveis'
                        : widget.companyMode
                            ? 'Serviços da empresa'
                            : 'Serviços disponíveis')
                : 'Resultados em $selectedCategory',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${list.length} resultado(s) encontrado(s)',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 42,
                    color: Colors.black45,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Nenhum serviço encontrado.',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tente mudar a busca ou selecionar outra categoria.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            )
          else
            ...list.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RequestCard(
                  job: job,
                  onChanged: loadJobs,
                  onTap: () => openJobDetails(job),
                  adminMode: widget.adminMode,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AllServicesPage extends StatefulWidget {
  final String fixedCategory;
  final Future<void> Function()? onChanged;
  final bool adminMode;
  final bool workerMode;
  final bool companyMode;

  const AllServicesPage({
    super.key,
    this.fixedCategory = 'Todos',
    this.onChanged,
    this.adminMode = false,
    this.workerMode = false,
    this.companyMode = false,
  });

  @override
  State<AllServicesPage> createState() => _AllServicesPageState();
}

class _AllServicesPageState extends State<AllServicesPage> {
  final TextEditingController searchController = TextEditingController();
  List<JobModel> jobs = [];
  bool loading = true;
  String selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.fixedCategory;
    loadJobs();
    searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadJobs() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      dynamic response;
      if (widget.adminMode) {
        response = await supabase
            .from('jobs')
            .select()
            .order('created_at', ascending: false);
      } else if (widget.workerMode) {
        response = await supabase
            .from('jobs')
            .select()
            .neq('client_id', user.id)
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('jobs')
            .select()
            .eq('client_id', user.id)
            .order('created_at', ascending: false);
      }

      jobs = (response as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      await refreshAllVisiblePayments(jobs);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<JobModel> get filteredJobs {
    final q = searchController.text.trim().toLowerCase();

    return jobs.where((job) {
      final categoryOk =
          selectedCategory == 'Todos' || job.category == selectedCategory;

      final searchOk = q.isEmpty ||
          job.title.toLowerCase().contains(q) ||
          job.description.toLowerCase().contains(q) ||
          job.publicLocationLabel.toLowerCase().contains(q) ||
          job.category.toLowerCase().contains(q) ||
          job.subservice.toLowerCase().contains(q);

      return categoryOk && searchOk;
    }).toList();
  }

  void openJobDetails(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsPage(
          job: job,
          onChanged: () async {
            await loadJobs();
            if (widget.onChanged != null) await widget.onChanged!();
          },
          adminMode: widget.adminMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = filteredJobs;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adminMode
            ? 'Todos os serviços (ADM)'
            : widget.workerMode
                ? 'Todas as oportunidades'
                : 'Todos os serviços'),
      ),
      body: RefreshIndicator(
        onRefresh: loadJobs,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: widget.workerMode ? 'Buscar oportunidades...' : 'Buscar serviços...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HomePage.categories.map((category) {
                final selected = selectedCategory == category;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFF4C61D)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(categoryIcon(category), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (list.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(widget.workerMode ? 'Nenhuma oportunidade encontrada.' : 'Nenhum serviço encontrado.'),
                ),
              )
            else
              ...list.map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RequestCard(
                    job: job,
                    onChanged: loadJobs,
                    onTap: () => openJobDetails(job),
                    adminMode: widget.adminMode,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class JobDetailsPage extends StatelessWidget {
  final JobModel job;
  final Future<void> Function()? onChanged;
  final bool adminMode;

  const JobDetailsPage({
    super.key,
    required this.job,
    this.onChanged,
    this.adminMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = adminMode || supabase.auth.currentUser?.id == job.clientId;
    final canConclude =
        adminMode ||
        (supabase.auth.currentUser?.id == job.clientId &&
            job.status == 'in_progress');
    final canReview = job.status == 'done';
    final currentUserId = supabase.auth.currentUser?.id;
    final isAssignedWorker =
        currentUserId != null && currentUserId == job.workerId;
    final canViewExactLocation =
        adminMode || currentUserId == job.clientId || isAssignedWorker;

    return Scaffold(
      appBar: AppBar(
        title: Text(job.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EFEB),
              borderRadius: BorderRadius.circular(22),
              image: job.photoUrl != null && job.photoUrl!.trim().isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(job.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: job.photoUrl != null && job.photoUrl!.trim().isNotEmpty
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0x88000000), Color(0x11000000)],
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      categoryIcon(job.category),
                      size: 70,
                      color: Colors.black87,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            job.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            job.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoTag(
                icon: categoryIcon(job.category),
                text: job.category,
              ),
              if (job.subservice.isNotEmpty)
                _InfoTag(
                  icon: Icons.tune,
                  text: job.subservice,
                ),
              _InfoTag(
                icon: Icons.location_on_outlined,
                text: job.publicLocationLabel,
              ),
              _InfoTag(
                icon: Icons.attach_money,
                text: money(job.price),
              ),
              _InfoTag(
                icon: Icons.flag_outlined,
                text: statusLabel(job.status),
              ),
              _InfoTag(
                icon: Icons.account_balance_wallet_outlined,
                text: paymentStatusLabel(job.paymentStatus),
              ),
              _InfoTag(
                icon: Icons.lock_clock_outlined,
                text: escrowStatusLabel(job.escrowStatus),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if ((job.exactAddress ?? '').isNotEmpty && canViewExactLocation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Localização exata',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(job.exactAddress!),
                  const SizedBox(height: 6),
                  Text(
                    'Coordenadas: ${formatCoordinates(job.latitude, job.longitude)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          else if ((job.exactAddress ?? '').isNotEmpty && !canViewExactLocation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8DE),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5C14A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_off_outlined, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Endereço protegido',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Local aproximado: ${job.publicLocationLabel}. O endereço exato é liberado ao prestador vinculado ao serviço.',
                    style: const TextStyle(color: Colors.black87, height: 1.35),
                  ),
                ],
              ),
            ),
          Text(
            'Publicado em ${formatDate(job.createdAt)}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          RequestCard(
            job: job,
            onChanged: onChanged,
            forceOwnerMode: isOwner,
            adminMode: adminMode,
          ),
          const SizedBox(height: 12),
          if (canConclude)
            const Text(
              'Este serviço pode ser concluído aqui.',
              style: TextStyle(color: Colors.black54),
            ),
          if (canReview)
            const Text(
              'Este serviço já pode ser avaliado.',
              style: TextStyle(color: Colors.black54),
            ),
        ],
      ),
    );
  }
}

class CreateJobResult {
  final String title;
  final String description;
  final String category;
  final String subservice;
  final String location;
  final String exactAddress;
  final String photoUrl;
  final double latitude;
  final double longitude;
  final double price;

  const CreateJobResult({
    required this.title,
    required this.description,
    required this.category,
    required this.subservice,
    required this.location,
    required this.exactAddress,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.price,
  });
}

class CreateJobPage extends StatefulWidget {
  final List<String> categories;

  const CreateJobPage({
    super.key,
    required this.categories,
  });

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final locationController = TextEditingController();
  final exactAddressController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController(text: supportedLaunchState);
  final photoUrlController = TextEditingController();
  final mapsUrlController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();
  final priceController = TextEditingController();

  late String selectedCategory;
  late String selectedSubservice;
  bool pickingPhoto = false;
  bool locating = false;

  String get selectedPhotoUrl => photoUrlController.text.trim();
  bool get hasSelectedLocation =>
      latitudeController.text.trim().isNotEmpty && longitudeController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.categories.first;
    selectedSubservice = subservicesForCategory(selectedCategory).first;
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    locationController.dispose();
    exactAddressController.dispose();
    cityController.dispose();
    stateController.dispose();
    photoUrlController.dispose();
    mapsUrlController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> chooseJobPhoto() async {
    final user = supabase.auth.currentUser;
    if (user == null || pickingPhoto) return;

    setState(() => pickingPhoto = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 72,
        requestFullMetadata: false,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('A imagem selecionada está vazia. Escolha outra foto.');
      }

      final safeCategory = selectedCategory
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${safeCategory.isEmpty ? 'servico' : safeCategory}.jpg';

      await supabase.storage.from('job-photos').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = supabase.storage.from('job-photos').getPublicUrl(fileName);

      if (!mounted) return;
      setState(() {
        photoUrlController.text = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto do serviço adicionada com sucesso.')),
      );
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao enviar foto: ${e.message}. Confira se existe um bucket público chamado job-photos no Supabase Storage.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao tirar/enviar foto. Verifique a permissão da câmera do celular e tente novamente. Detalhe: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  Future<void> openPhotoOptions() async {
    if (pickingPhoto) return;
    await chooseJobPhoto();
  }

  Future<bool> ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative a localização/GPS do celular para usar esta função.')),
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de localização negada. Autorize para usar localização atual.')),
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de localização bloqueada. Libere nas configurações do celular.')),
      );
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  Future<void> useCurrentLocation() async {
    if (locating) return;
    setState(() => locating = true);

    try {
      final allowed = await ensureLocationPermission();
      if (!allowed) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      if (!mounted) return;
      setState(() {
        latitudeController.text = lat.toStringAsFixed(7);
        longitudeController.text = lng.toStringAsFixed(7);
        mapsUrlController.text = mapsUrl;
        if (exactAddressController.text.trim().isEmpty) {
          exactAddressController.text = 'Localização atual aproximada';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Localização atual capturada com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao pegar localização atual: $e')),
      );
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void readGoogleMapsLink() {
    final coords = extractCoordsFromGoogleMaps(mapsUrlController.text.trim());
    final lat = coords['lat'];
    final lng = coords['lng'];
    if (lat != null && lng != null) {
      setState(() {
        latitudeController.text = lat.toString();
        longitudeController.text = lng.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordenadas lidas do link do Google Maps.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui ler as coordenadas do link. Use o botão de localização atual ou cole um link compartilhado do Google Maps.')),
      );
    }
  }

  Future<void> openSelectedLocationInMaps() async {
    final lat = double.tryParse(latitudeController.text.replaceAll(',', '.'));
    final lng = double.tryParse(longitudeController.text.replaceAll(',', '.'));
    Uri? uri;

    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else if (exactAddressController.text.trim().isNotEmpty) {
      uri = tryBuildMapsUri(exactAddressController.text.trim());
    } else if (locationController.text.trim().isNotEmpty) {
      uri = tryBuildMapsUri(locationController.text.trim());
    }

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ou capture uma localização primeiro.')),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void save() {
    final title = titleController.text.trim();
    final desc = descController.text.trim();
    final selectedCity = normalizeLaunchCity(cityController.text.trim());
    final selectedState = normalizedUf(stateController.text);
    final neighborhood = locationController.text.trim();
    final location = selectedCity.isNotEmpty
        ? (neighborhood.isNotEmpty
            ? '$neighborhood • $selectedCity/$selectedState'
            : '$selectedCity/$selectedState')
        : neighborhood;
    final exactAddress = exactAddressController.text.trim();
    final photoUrl = photoUrlController.text.trim();
    final latitude = double.tryParse(latitudeController.text.replaceAll(',', '.'));
    final longitude = double.tryParse(longitudeController.text.replaceAll(',', '.'));
    final price = double.tryParse(priceController.text.replaceAll(',', '.'));

    if (title.isEmpty ||
        desc.isEmpty ||
        location.isEmpty ||
        selectedState != supportedLaunchState ||
        !isScCity(selectedCity) ||
        exactAddress.isEmpty ||
        photoUrl.isEmpty ||
        latitude == null ||
        longitude == null ||
        price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha título, descrição, estado e cidade de SC, endereço, foto, localização e preço.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      CreateJobResult(
        title: title,
        description: desc,
        category: selectedCategory,
        subservice: selectedSubservice,
        location: location,
        exactAddress: exactAddress,
        photoUrl: photoUrl,
        latitude: latitude,
        longitude: longitude,
        price: price,
      ),
    );
  }

  Widget photoPickerCard() {
    final hasPhoto = selectedPhotoUrl.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasPhoto ? Colors.green : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF4C61D),
                child: Icon(hasPhoto ? Icons.check : Icons.photo_camera_outlined, color: Colors.black),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPhoto ? 'Foto adicionada' : 'Foto do serviço',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasPhoto ? 'A imagem já foi enviada com segurança.' : 'Obrigatório. Tire uma foto agora com a câmera do celular.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                selectedPhotoUrl,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: const Color(0xFFF6F2EF),
                  alignment: Alignment.center,
                  child: const Text('Foto enviada, mas a prévia não carregou.'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: pickingPhoto ? null : openPhotoOptions,
              icon: pickingPhoto
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(hasPhoto ? 'Trocar foto' : 'Adicionar foto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4C61D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget locationPickerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasSelectedLocation ? Colors.green : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF4C61D),
                child: Icon(hasSelectedLocation ? Icons.check : Icons.my_location, color: Colors.black),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSelectedLocation ? 'Localização capturada' : 'Localização do serviço',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasSelectedLocation
                          ? 'Coordenadas: ${latitudeController.text}, ${longitudeController.text}'
                          : 'Use GPS em tempo real/aproximado ou cole um link do Google Maps.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: locating ? null : useCurrentLocation,
              icon: locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(locating ? 'Buscando localização...' : 'Usar minha localização atual'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4C61D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: openSelectedLocationInMaps,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Abrir no Maps'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: readGoogleMapsLink,
                  icon: const Icon(Icons.link),
                  label: const Text('Ler link'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InputField(
            controller: mapsUrlController,
            hint: 'Link do Google Maps (opcional)',
          ),
        ],
      ),
    );
  }


  Widget createJobStateDropdown() {
    final currentState = normalizedUf(stateController.text);
    final selectedValue = currentState == supportedLaunchState
        ? currentState
        : supportedLaunchState;

    return DropdownButtonFormField<String>(
      value: selectedValue,
      isExpanded: true,
      decoration: fieldDecoration('Estado'),
      items: brazilStatesLaunchOptions.map((state) {
        final uf = state.substring(0, 2);
        final locked = uf != supportedLaunchState;
        return DropdownMenuItem<String>(
          value: uf,
          enabled: !locked,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: locked ? Colors.black38 : Colors.black87,
                  ),
                ),
              ),
              if (locked)
                const Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Colors.black38,
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (selected) {
        if (selected == null) return;
        if (selected != supportedLaunchState) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este estado será liberado em breve.'),
            ),
          );
          return;
        }
        setState(() {
          stateController.text = supportedLaunchState;
          if (!isScCity(cityController.text)) {
            cityController.clear();
          }
        });
      },
    );
  }

  Widget createJobCityDropdown() {
    final cities = uniqueScCities();
    final current = isScCity(cityController.text) ? normalizeLaunchCity(cityController.text) : null;
    return DropdownButtonFormField<String>(
      value: current,
      isExpanded: true,
      decoration: fieldDecoration('Cidade/Município do serviço'),
      items: cities
          .map(
            (city) => DropdownMenuItem<String>(
              value: city,
              child: Text(city, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (city) {
        if (city == null) return;
        setState(() {
          cityController.text = city;
          stateController.text = supportedLaunchState;
          if (locationController.text.trim().isEmpty || locationController.text.trim() == 'Perto de mim') {
            locationController.text = '$city/$supportedLaunchState';
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EF),
      appBar: AppBar(
        title: const Text('Publicar serviço'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          InputField(
            controller: titleController,
            hint: 'Título do serviço',
          ),
          const SizedBox(height: 12),
          InputField(
            controller: descController,
            hint: 'Descrição',
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: fieldDecoration('Categoria'),
            items: widget.categories
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedCategory = value;
                  selectedSubservice = subservicesForCategory(value).first;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedSubservice,
            decoration: fieldDecoration('Subserviço'),
            items: subservicesForCategory(selectedCategory)
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedSubservice = value);
              }
            },
          ),
          const SizedBox(height: 12),
          createJobStateDropdown(),
          const SizedBox(height: 12),
          createJobCityDropdown(),
          const SizedBox(height: 6),
          const Text(
            'No lançamento, a publicação de serviços está disponível somente em Santa Catarina. Os demais estados serão liberados gradualmente.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          InputField(
            controller: locationController,
            hint: 'Bairro / região do serviço',
          ),
          const SizedBox(height: 12),
          InputField(
            controller: exactAddressController,
            hint: 'Endereço exato ou ponto de referência',
          ),
          const SizedBox(height: 6),
          const Text(
            'Privacidade: antes da contratação, o prestador vê apenas bairro/região e cidade. O endereço exato fica protegido e é liberado ao prestador vinculado ao serviço.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          locationPickerCard(),
          const SizedBox(height: 12),
          photoPickerCard(),
          const SizedBox(height: 12),
          InputField(
            controller: priceController,
            hint: 'Preço',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: (pickingPhoto || locating) ? null : save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4C61D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Salvar serviço',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class MyServicesPage extends StatefulWidget {
  final bool adminMode;

  const MyServicesPage({
    super.key,
    this.adminMode = false,
  });

  @override
  State<MyServicesPage> createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage> {
  List<JobModel> myJobs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadMyJobs();
  }

  Future<void> loadMyJobs() async {
    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      dynamic response;
      if (widget.adminMode) {
        response = await supabase
            .from('jobs')
            .select()
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('jobs')
            .select()
            .eq('client_id', user.id)
            .order('created_at', ascending: false);
      }

      myJobs = (response as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      await refreshAllVisiblePayments(myJobs);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void openJobDetails(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsPage(
          job: job,
          onChanged: loadMyJobs,
          adminMode: widget.adminMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adminMode ? 'Serviços (ADM)' : 'Meus serviços'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadMyJobs,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: myJobs.isEmpty
                    ? const [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Text('Nenhum serviço encontrado.'),
                          ),
                        )
                      ]
                    : myJobs
                        .map(
                          (job) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RequestCard(
                              job: job,
                              onChanged: loadMyJobs,
                              forceOwnerMode: true,
                              onTap: () => openJobDetails(job),
                              adminMode: widget.adminMode,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
    );
  }
}

class ReviewsPage extends StatefulWidget {
  final bool adminMode;

  const ReviewsPage({
    super.key,
    this.adminMode = false,
  });

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  List<ReviewModel> reviews = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadReviews();
  }

  Future<void> loadReviews() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      dynamic response;
      if (widget.adminMode) {
        response = await supabase
            .from('reviews')
            .select()
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('reviews')
            .select()
            .eq('reviewed_id', user.id)
            .order('created_at', ascending: false);
      }

      reviews = (response as List)
          .map((e) => ReviewModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double get average {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<double>(0, (sum, item) => sum + item.rating);
    return total / reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adminMode ? 'Avaliações (ADM)' : 'Avaliações'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.adminMode ? 'Média geral da plataforma' : 'Média geral',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${average.toStringAsFixed(1)} ⭐',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${reviews.length} avaliações'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (reviews.isEmpty)
                  const Text('Nenhuma avaliação ainda.')
                else
                  ...reviews.map(
                    (review) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${review.rating.toStringAsFixed(1)} ⭐',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            review.comment.isEmpty
                                ? 'Sem comentário.'
                                : review.comment,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatDate(review.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class ChatListPage extends StatefulWidget {
  final bool adminMode;

  const ChatListPage({
    super.key,
    this.adminMode = false,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<JobModel> chatJobs = [];
  final Map<String, Map<String, dynamic>> chatProfiles = {};
  final Map<String, int> unreadByJobId = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadChatJobs();
  }

  Future<void> loadChatJobs() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      dynamic response;
      if (widget.adminMode) {
        response = await supabase
            .from('jobs')
            .select()
            .not('worker_id', 'is', null)
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('jobs')
            .select()
            .or('client_id.eq.${user.id},worker_id.eq.${user.id}')
            .not('worker_id', 'is', null)
            .order('created_at', ascending: false);
      }

      chatJobs = (response as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      await loadParticipantProfilesForJobs(chatJobs);
      await loadUnreadCountsForJobs(chatJobs);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadParticipantProfilesForJobs(List<JobModel> jobs) async {
    final ids = <String>{};
    for (final job in jobs) {
      if (job.clientId.trim().isNotEmpty) ids.add(job.clientId);
      final workerId = job.workerId;
      if (workerId != null && workerId.trim().isNotEmpty) ids.add(workerId);
    }

    if (ids.isEmpty) return;

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .inFilter('id', ids.toList());

      chatProfiles
        ..clear()
        ..addEntries(
          (response as List).map((item) {
            final profile = Map<String, dynamic>.from(item);
            return MapEntry((profile['id'] ?? '').toString(), profile);
          }),
        );
    } catch (_) {
      // Se não conseguir carregar nomes, a lista de chats continua funcionando.
    }
  }


  Future<void> loadUnreadCountsForJobs(List<JobModel> jobs) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final jobIds = jobs.map((job) => job.id).where((id) => id.trim().isNotEmpty).toList();
    if (jobIds.isEmpty) {
      unreadByJobId.clear();
      return;
    }

    try {
      final response = await supabase
          .from('messages')
          .select('id, job_id, sender_id, is_read')
          .inFilter('job_id', jobIds)
          .eq('is_read', false)
          .neq('sender_id', user.id);

      final counts = <String, int>{};
      for (final item in (response as List)) {
        final map = Map<String, dynamic>.from(item);
        final jobId = (map['job_id'] ?? '').toString();
        if (jobId.isEmpty) continue;
        counts[jobId] = (counts[jobId] ?? 0) + 1;
      }

      unreadByJobId
        ..clear()
        ..addAll(counts);
    } catch (_) {
      // O contador é complementar. Se falhar, a lista de chats continua normal.
    }
  }

  String chatParticipantName(String? userId) {
    if (userId == null || userId.trim().isEmpty) return 'Nome não disponível';
    return displayProfileNameFromMap(
      chatProfiles[userId],
      fallback: 'Nome não disponível',
    );
  }

  String chatSubtitleForJob(JobModel job) {
    final currentUserId = supabase.auth.currentUser?.id ?? '';
    final clientName = chatParticipantName(job.clientId);
    final workerName = chatParticipantName(job.workerId);

    if (widget.adminMode) {
      return '$clientName ↔ $workerName • ${job.category}';
    }

    if (currentUserId == job.clientId) {
      return '$workerName • ${job.category}';
    }

    if (currentUserId == job.workerId) {
      return '$clientName • ${job.category}';
    }

    return '${job.category} • $clientName ↔ $workerName';
  }

  Future<void> openChat(JobModel job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          jobId: job.id,
          jobTitle: job.title,
          initialProfiles: {
            if (chatProfiles[job.clientId] != null) job.clientId: chatProfiles[job.clientId]!,
            if (job.workerId != null && chatProfiles[job.workerId!] != null) job.workerId!: chatProfiles[job.workerId!]!,
          },
        ),
      ),
    );
    await loadChatJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adminMode ? 'Conversas (ADM)' : 'Conversas'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadChatJobs,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: chatJobs.isEmpty
                    ? const [
                        Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text('Nenhuma conversa disponível ainda.'),
                          ),
                        )
                      ]
                    : chatJobs
                        .map(
                          (job) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              onTap: () => openChat(job),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFF4C61D),
                                child: Icon(
                                  categoryIcon(job.category),
                                  color: Colors.black,
                                ),
                              ),
                              title: Text(
                                job.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                chatSubtitleForJob(job),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Builder(
                                builder: (_) {
                                  final unread = unreadByJobId[job.id] ?? 0;
                                  if (unread <= 0) {
                                    return const Icon(Icons.chevron_right);
                                  }
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4C61D),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: Colors.black, width: 1.2),
                                        ),
                                        child: Text(
                                          unread > 99 ? '99+' : '$unread',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final Map<String, Map<String, dynamic>> initialProfiles;

  const ChatPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
    this.initialProfiles = const {},
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  final Map<String, Map<String, dynamic>> senderProfiles = {};
  bool sending = false;
  String conversationName = 'Conversa';
  String? conversationTargetUserId;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfiles.isNotEmpty) {
      senderProfiles.addAll(widget.initialProfiles);
    }
    loadConversationHeader();
  }

  Future<void> loadConversationHeader() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final jobData = await supabase
          .from('jobs')
          .select('client_id, worker_id')
          .eq('id', widget.jobId)
          .maybeSingle();

      if (jobData == null) return;

      final clientId = (jobData['client_id'] ?? '').toString().trim();
      final workerId = (jobData['worker_id'] ?? '').toString().trim();

      final ids = <String>{
        if (clientId.isNotEmpty) clientId,
        if (workerId.isNotEmpty) workerId,
      };

      final missing = ids
          .where((id) => !senderProfiles.containsKey(id))
          .toList();

      if (missing.isNotEmpty) {
        final response = await supabase
            .from('profiles')
            .select(
              'id, email, name, role, company_trade_name, company_legal_name, company_responsible, foto_url',
            )
            .inFilter('id', missing);

        for (final item in (response as List)) {
          final profile = Map<String, dynamic>.from(item);
          final id = (profile['id'] ?? '').toString();
          if (id.isNotEmpty) senderProfiles[id] = profile;
        }
      }

      String resolvedName;
      String? targetUserId;

      if (currentUser.id == clientId && workerId.isNotEmpty) {
        targetUserId = workerId;
        resolvedName = displayProfileNameFromMap(
          senderProfiles[workerId],
          fallback: 'Nome não disponível',
        );
      } else if (currentUser.id == workerId && clientId.isNotEmpty) {
        targetUserId = clientId;
        resolvedName = displayProfileNameFromMap(
          senderProfiles[clientId],
          fallback: 'Nome não disponível',
        );
      } else {
        final clientName = displayProfileNameFromMap(
          senderProfiles[clientId],
          fallback: 'Nome não disponível',
        );
        final workerName = displayProfileNameFromMap(
          senderProfiles[workerId],
          fallback: 'Nome não disponível',
        );
        resolvedName = '$clientName ↔ $workerName';
      }

      if (!mounted) return;
      setState(() {
        conversationName = resolvedName;
        conversationTargetUserId = targetUserId;
      });
    } catch (_) {
      // O título do serviço continua disponível caso o nome não carregue.
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final user = supabase.auth.currentUser;
    final text = messageController.text.trim();

    if (user == null || text.isEmpty || sending) return;

    setState(() => sending = true);

    try {
      final localSafety = EmbeddedSafetyAI.inspect(text);
      if (localSafety.blocked) {
        await EmbeddedSafetyAI.registerEvent(
          sourceType: 'chat',
          sourceId: widget.jobId,
          content: text,
          result: localSafety,
        );
        await analisarMensagem(text);
      }

      if (mensagemSuspeita(text)) {
        await moderateMessageWithEdgeFunction(text);
        await EmbeddedSafetyAI.registerEvent(
          sourceType: 'chat',
          sourceId: widget.jobId,
          content: text,
          result: const SafetyCheckResult(
            blocked: false,
            flagged: true,
            reason: 'Mensagem suspeita detectada',
          ),
        );
        await analisarMensagem(text);
      }

      await supabase.from('messages').insert({
        'job_id': widget.jobId,
        'sender_id': user.id,
        'text': text,
        'is_read': false,
      });

      try {
        final jobData = await supabase
            .from('jobs')
            .select('client_id, worker_id, title')
            .eq('id', widget.jobId)
            .maybeSingle();

        if (jobData != null) {
          final clientId = jobData['client_id']?.toString();
          final workerId = jobData['worker_id']?.toString();
          final receiverId = clientId == user.id ? workerId : clientId;

          if (receiverId != null && receiverId.isNotEmpty && receiverId != user.id) {
            await createNotificationForUser(
              userId: receiverId,
              title: 'Nova mensagem no PegaeFazFree',
              body: '${widget.jobTitle}: $text',
              referenceType: 'chat',
              referenceId: widget.jobId,
            );
          }
        }
      } catch (_) {}

      messageController.clear();

      await Future.delayed(const Duration(milliseconds: 120));
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

Future<void> analisarMensagem(String text) async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  var warnings = 1;

  try {
    final profile = await supabase
        .from('profiles')
        .select('warning_count')
        .eq('id', user.id)
        .maybeSingle();

    warnings = ((profile?['warning_count'] ?? 0) as num).toInt() + 1;

    await supabase
        .from('profiles')
        .update({'warning_count': warnings})
        .eq('id', user.id);
  } catch (_) {
    // Se a coluna warning_count ainda não existir no Supabase,
    // o app continua funcionando e apenas mostra o aviso local.
    warnings = 1;
  }

  if (warnings >= 4) {
    await supabase
        .from('profiles')
        .update({'is_blocked': true})
        .eq('id', user.id);

    throw Exception('🚫 Conta bloqueada por tentativa de fraude.');
  }

  throw Exception(
    '⚠️ Aviso $warnings/4: Não compartilhe contato ou pagamento fora da plataforma.',
  );
}

  Future<void> loadSenderProfilesForMessages(List<MessageModel> messages) async {
    final missingIds = messages
        .map((m) => m.senderId)
        .where((id) => id.trim().isNotEmpty && !senderProfiles.containsKey(id))
        .toSet()
        .toList();

    if (missingIds.isEmpty) return;

    try {
      final response = await supabase
          .from('profiles')
          .select('id, email, name, role, company_trade_name, company_legal_name, company_responsible, foto_url')
          .inFilter('id', missingIds);

      final updates = <String, Map<String, dynamic>>{};
      for (final item in (response as List)) {
        final profile = Map<String, dynamic>.from(item);
        updates[(profile['id'] ?? '').toString()] = profile;
      }

      if (updates.isNotEmpty && mounted) {
        setState(() {
          senderProfiles.addAll(updates);
        });
      }
    } catch (_) {
      // O chat não pode parar caso o nome do remetente não carregue.
    }
  }

  String senderDisplayName(MessageModel message, bool isMe) {
    final profile = senderProfiles[message.senderId];
    final name = displayProfileNameFromMap(
      profile,
      fallback: 'Nome não disponível',
    );
    if (isMe) {
      return name == 'Equipe PegaeFazFree' ? 'Você • Equipe PegaeFazFree' : 'Você';
    }
    return name;
  }

  void openSenderProfile(String userId) {
    if (userId.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(profileId: userId),
      ),
    );
  }

  bool senderIsOfficial(MessageModel message) {
    final profile = senderProfiles[message.senderId];
    final email = profile?['email']?.toString();
    final role = (profile?['role'] ?? '').toString();
    return role == roleAdmin || isPrivilegedAdminEmail(email);
  }

  Future<void> reportConversationUser() async {
    final targetId = (conversationTargetUserId ?? '').trim();
    if (targetId.isEmpty) return;

    await showUserReportDialog(
      context,
      reportedUserId: targetId,
      reportedDisplayName: displayProfileNameFromMap(
        senderProfiles[targetId],
        fallback: conversationName,
      ),
      source: 'chat',
      jobId: widget.jobId,
    );
  }

  Future<void> reportChatMessage(MessageModel message) async {
    if (message.senderId.trim().isEmpty) return;

    await showUserReportDialog(
      context,
      reportedUserId: message.senderId,
      reportedDisplayName: senderDisplayName(message, false),
      source: 'chat_message',
      jobId: widget.jobId,
      messageId: message.id,
    );
  }

  Future<void> markMessagesAsRead(List<MessageModel> messages) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unread = messages
        .where((m) => !m.isRead && m.senderId != user.id)
        .map((m) => m.id)
        .toList();

    if (unread.isEmpty) return;

    await supabase.from('messages').update({'is_read': true}).inFilter('id', unread);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DD),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.chat_bubble_outline,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    widget.jobTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if ((conversationTargetUserId ?? '').trim().isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Opções da conversa',
              onSelected: (value) {
                if (value == 'report') reportConversationUser();
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text('Denunciar usuário'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('job_id', widget.jobId)
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!
                    .map((e) => MessageModel.fromMap(e))
                    .toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  loadSenderProfilesForMessages(messages);
                  markMessagesAsRead(messages);
                  if (scrollController.hasClients &&
                      scrollController.position.maxScrollExtent > 0) {
                    scrollController.jumpTo(
                      scrollController.position.maxScrollExtent,
                    );
                  }
                });

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma mensagem ainda. Comece a conversa.'),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    final senderName = senderDisplayName(message, isMe);
                    final officialSender = senderIsOfficial(message);

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFFDCF8C6)
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (officialSender) ...[
                                    const Icon(Icons.verified_user, size: 14, color: Colors.black87),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: InkWell(
                                      onTap: () => openSenderProfile(message.senderId),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text(
                                          senderName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            decoration: TextDecoration.underline,
                                            color: officialSender ? Colors.black : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!isMe && !officialSender) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => reportChatMessage(message),
                                      borderRadius: BorderRadius.circular(12),
                                      child: const Padding(
                                        padding: EdgeInsets.all(3),
                                        child: Icon(
                                          Icons.flag_outlined,
                                          size: 15,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                message.text,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _timeLabel(message.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              color: const Color(0xFFF6F2EF),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: messageController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Digite uma mensagem',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF25D366),
                    child: IconButton(
                      onPressed: sendMessage,
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}


class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}


class _WorkerHomePageState extends State<WorkerHomePage> {
  bool loading = true;
  List<JobModel> availableJobs = [];
  List<JobModel> assignedJobs = [];
  ProfileModel? profile;
  WorkerResumeModel? resume;
  WorkerTrustModel trust = const WorkerTrustModel(workerId: '');
  double ratingAverage = 0;
  int ratingCount = 0;
  PffFinancialMetrics financialMetrics = const PffFinancialMetrics(
    today: 0,
    month: 0,
    year: 0,
    total: 0,
    completed: 0,
    inProgress: 0,
    proposalsSent: 0,
    proposalsAccepted: 0,
    monthlyValues: [0, 0, 0, 0, 0, 0],
    monthlyLabels: ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun'],
  );

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      try {
        await syncReceivingConnectionStatus().timeout(const Duration(seconds: 8));
      } catch (_) {}
      profile = await getCurrentProfile();

      final availableResponse = await supabase
          .from('jobs')
          .select()
          .neq('client_id', user.id)
          .order('created_at', ascending: false)
          .limit(8);
      availableJobs = (availableResponse as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      final assignedResponse = await supabase
          .from('jobs')
          .select()
          .eq('worker_id', user.id)
          .order('created_at', ascending: false)
          .limit(12);
      assignedJobs = (assignedResponse as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      final resumeResponse = await supabase
          .from('worker_resumes')
          .select()
          .eq('worker_id', user.id)
          .maybeSingle();
      if (resumeResponse != null) {
        resume = WorkerResumeModel.fromMap(Map<String, dynamic>.from(resumeResponse));
      }

      trust = await loadWorkerTrust(user.id);

      final trustMetrics = await loadUserTrustMetrics(user.id, role: roleWorker);
      ratingCount = trustMetrics.ratingCount;
      ratingAverage = trustMetrics.ratingAverage;
      financialMetrics = await loadWorkerFinancialMetrics(user.id);
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _metric(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _financialSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resumo de faturamento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            PffMetricCard(title: 'Hoje', value: money(financialMetrics.today), icon: Icons.today_outlined),
            PffMetricCard(title: 'Este mês', value: money(financialMetrics.month), icon: Icons.calendar_month_outlined),
            PffMetricCard(title: 'Este ano', value: money(financialMetrics.year), icon: Icons.bar_chart_outlined),
            PffMetricCard(title: 'Total recebido', value: money(financialMetrics.total), icon: Icons.account_balance_wallet_outlined),
          ],
        ),
        const SizedBox(height: 12),
        PffDashboardBarChart(
          title: 'Faturamento dos últimos 6 meses',
          labels: financialMetrics.monthlyLabels,
          values: financialMetrics.monthlyValues,
          moneyValues: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inProgressCount = financialMetrics.inProgress;
    final completedCount = financialMetrics.completed;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadData,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF7D91A), Color(0xFFE4A60B)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.handyman_outlined, size: 34, color: Colors.black),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile?.name ?? 'Prestador', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(profile?.specialty?.isNotEmpty == true ? profile!.specialty! : 'Profissional do PegaeFazFree', style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (trust.identityVerified || trust.pioneerBadge) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (trust.identityVerified)
                                      const Chip(
                                        avatar: Icon(Icons.verified_user, size: 17),
                                        label: Text('Identidade verificada'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    if (trust.pioneerBadge)
                                      const Chip(
                                        avatar: Icon(Icons.workspace_premium_outlined, size: 17),
                                        label: Text('Pioneiro PegaeFazFree'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Seu painel profissional', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      profile?.receivingReady == true
                          ? 'Recebimentos ativos. Acompanhe jobs, currículo, chats, ganhos e avaliações.'
                          : profile?.receivingUnderReview == true
                              ? 'Sua conta de recebimento está conectada e em análise. Você pode acompanhar o status pelo perfil.'
                              : profile?.hasReceivingAccount == true
                                  ? 'Sua conta de recebimento foi criada. Continue a configuração para liberar os repasses.'
                                  : 'Você já pode buscar jobs e enviar propostas. Configure os recebimentos apenas quando for usar pagamentos pela plataforma.',
                      style: const TextStyle(color: Colors.black87, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Row(
                  children: [
                    _metric('Jobs em andamento', '$inProgressCount', Icons.timelapse),
                    const SizedBox(width: 12),
                    _metric('Serviços concluídos', '$completedCount', Icons.verified_outlined),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metric('Avaliação', ratingCount == 0 ? '0.0' : ratingAverage.toStringAsFixed(1), Icons.star_outline),
                    const SizedBox(width: 12),
                    _metric('Propostas aceitas', '${financialMetrics.proposalsAccepted}', Icons.check_circle_outline),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metric('Propostas enviadas', '${financialMetrics.proposalsSent}', Icons.send_outlined),
                    const SizedBox(width: 12),
                    _metric(
                      'Recebimentos',
                      profile?.receivingStatusLabel ?? 'Não conectado',
                      Icons.account_balance_wallet_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _financialSummary(),
                const SizedBox(height: 18),
                PffActionTile(
                  title: 'Buscar jobs disponíveis',
                  subtitle: 'Veja novas oportunidades e envie propostas.',
                  icon: Icons.work_outline,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerJobsPage())),
                ),
                const SizedBox(height: 10),
                PffActionTile(
                  title: 'Meu currículo profissional',
                  subtitle: resume == null ? 'Crie seu currículo para ser encontrado por empresas.' : 'Atualize seu currículo, conselho profissional e disponibilidade.',
                  icon: Icons.badge_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerResumePage())),
                ),
                const SizedBox(height: 10),
                PffActionTile(
                  title: 'Ranking e avaliações',
                  subtitle: 'Acompanhe seu posicionamento e sua reputação.',
                  icon: Icons.leaderboard_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerRankingPage())),
                ),
                const SizedBox(height: 10),
                PffActionTile(
                  title: 'Chats e negociações',
                  subtitle: 'Acesse conversas de jobs aceitos e em andamento.',
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListPage())),
                ),
                const SizedBox(height: 18),
                const Text('Jobs em andamento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (assignedJobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Você ainda não assumiu nenhum job.'),
                  )
                else
                  ...assignedJobs.take(3).map((job) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RequestCard(job: job, onChanged: loadData),
                      )),
                const SizedBox(height: 18),
                const Text('Novas oportunidades', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (availableJobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Nenhum job disponível no momento.'),
                  )
                else
                  ...availableJobs.take(3).map((job) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RequestCard(job: job, onChanged: loadData),
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CompanyHomePage extends StatefulWidget {
  const CompanyHomePage({super.key});

  @override
  State<CompanyHomePage> createState() => _CompanyHomePageState();
}


class _CompanyHomePageState extends State<CompanyHomePage> {
  bool loading = true;
  ProfileModel? profile;
  List<JobModel> jobs = [];
  bool hasResumeAccess = false;
  int talentsCount = 0;
  PffTrustMetrics trustMetrics = const PffTrustMetrics(
    ratingAverage: 0,
    ratingCount: 0,
    completedServices: 0,
    publishedServices: 0,
    contractedServices: 0,
    inProgressServices: 0,
    totalServices: 0,
    memberSince: 'Não informado',
  );
  List<double> monthlyDemand = const [0, 0, 0, 0, 0, 0];
  List<String> monthlyLabels = const ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun'];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      profile = await getCurrentProfile();
      final jobsResponse = await supabase
          .from('jobs')
          .select()
          .eq('client_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);
      jobs = (jobsResponse as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      trustMetrics = await loadUserTrustMetrics(user.id, role: roleClientCompany);

      monthlyLabels = lastSixMonthLabels();
      final values = List<double>.filled(6, 0);
      for (final job in jobs) {
        final index = monthIndexInLastSix(job.createdAt);
        if (index >= 0) values[index] += 1;
      }
      monthlyDemand = values;

      final accessResponse = await supabase
          .from('company_resume_access')
          .select()
          .eq('company_id', user.id)
          .maybeSingle();
      hasResumeAccess = accessResponse != null && accessResponse['is_active'] == true;

      try {
        final resumesResponse = await supabase
            .from('worker_resumes')
            .select('id')
            .eq('is_active', true);
        talentsCount = (resumesResponse as List).length;
      } catch (_) {
        talentsCount = 0;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openCreateJobPage() async {
    final result = await Navigator.push<CreateJobResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobPage(
          categories: HomePage.categories.where((e) => e != 'Todos').toList(),
        ),
      ),
    );

    if (result == null) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');

      final inserted = await supabase.from('jobs').insert({
        'title': result.title,
        'description': result.description,
        'category': result.category,
        'subservice': result.subservice,
        'location': result.location,
        'exact_address': result.exactAddress,
        'photo_url': result.photoUrl,
        'latitude': result.latitude,
        'longitude': result.longitude,
        'price': result.price,
        'client_id': user.id,
        'status': 'open',
      }).select('id').single();

      await notifyInterestedWorkersForJob(
        jobId: (inserted['id'] ?? '').toString(),
        category: result.category,
        title: result.title,
        location: result.location,
      );

      if (!mounted) return;
      await loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço da empresa publicado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao publicar serviço: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyName = profile?.companyTradeName?.trim().isNotEmpty == true
        ? profile!.companyTradeName!
        : profile?.companyLegalName?.trim().isNotEmpty == true
            ? profile!.companyLegalName!
            : profile?.name ?? 'Empresa';
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadData,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF7D91A), Color(0xFFE4A60B)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(companyName, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text(
                      'Painel da empresa para acompanhar demandas, contratações, reputação e banco de talentos.',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: openCreateJobPage,
                            icon: const Icon(Icons.add),
                            label: const Text('Publicar demanda'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    PffMetricCard(title: 'Serviços publicados', value: '${trustMetrics.publishedServices}', icon: Icons.assignment_outlined),
                    PffMetricCard(title: 'Serviços concluídos', value: '${trustMetrics.contractedServices}', icon: Icons.verified_outlined),
                    PffMetricCard(title: 'Em andamento', value: '${trustMetrics.inProgressServices}', icon: Icons.timelapse),
                    PffMetricCard(title: 'Avaliação', value: trustMetrics.ratingAverage.toStringAsFixed(1), icon: Icons.star_outline),
                    PffMetricCard(title: 'Avaliações', value: '${trustMetrics.ratingCount}', icon: Icons.rate_review_outlined),
                    PffMetricCard(title: 'Membro desde', value: trustMetrics.memberSince, icon: Icons.calendar_today_outlined),
                  ],
                ),
                const SizedBox(height: 12),
                PffDashboardBarChart(
                  title: 'Demandas publicadas nos últimos 6 meses',
                  labels: monthlyLabels,
                  values: monthlyDemand,
                ),
                const SizedBox(height: 18),
                PffActionTile(
                  title: 'Banco de talentos',
                  subtitle: hasResumeAccess
                      ? 'Acesso ativo. Existem $talentsCount currículo(s) disponível(is) para análise.'
                      : 'Solicite acesso para encontrar profissionais para sua empresa.',
                  icon: Icons.badge_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyResumeAccessPage())),
                ),
                const SizedBox(height: 10),
                PffActionTile(
                  title: 'Serviços da empresa',
                  subtitle: 'Acompanhe demandas abertas, em andamento e concluídas.',
                  icon: Icons.assignment_outlined,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyServicesPage())),
                ),
                const SizedBox(height: 10),
                PffActionTile(
                  title: 'Chats e negociações',
                  subtitle: 'Converse com prestadores sobre demandas da empresa.',
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListPage())),
                ),
                const SizedBox(height: 18),
                const Text('Últimas demandas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (jobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Sua empresa ainda não publicou serviços.'),
                  )
                else
                  ...jobs.take(3).map((job) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RequestCard(job: job, onChanged: loadData, forceOwnerMode: true),
                      )),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Text(
                    'Privacidade: métricas de currículos acessados ficam somente em telas privadas da empresa e no painel ADM. Elas não aparecem no perfil público.',
                    style: TextStyle(color: Colors.black54, height: 1.35, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WorkerJobsPage extends StatefulWidget {
  final bool adminMode;

  const WorkerJobsPage({
    super.key,
    this.adminMode = false,
  });

  @override
  State<WorkerJobsPage> createState() => _WorkerJobsPageState();
}

class _WorkerJobsPageState extends State<WorkerJobsPage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController neighborhoodFilterController = TextEditingController();
  final ScrollController categoriesScrollController = ScrollController();

  String selectedCategory = 'Todos';
  String selectedStateFilter = supportedLaunchState;
  String selectedCityFilter = 'Todas as cidades';
  int? selectedRadiusKm;
  double? workerFilterLatitude;
  double? workerFilterLongitude;
  bool loading = true;
  bool locatingFilter = false;
  bool showLeftArrow = false;
  List<JobModel> jobs = [];

  final List<String> categories = appCategories;

  @override
  void initState() {
    super.initState();
    loadJobs();

    searchController.addListener(() {
      if (mounted) setState(() {});
    });
    neighborhoodFilterController.addListener(() {
      if (mounted) setState(() {});
    });

    categoriesScrollController.addListener(() {
      if (!mounted || !categoriesScrollController.hasClients) return;
      final shouldShowLeft = categoriesScrollController.offset > 10;
      if (showLeftArrow != shouldShowLeft) {
        setState(() => showLeftArrow = shouldShowLeft);
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    neighborhoodFilterController.dispose();
    categoriesScrollController.dispose();
    super.dispose();
  }

  Future<void> loadJobs() async {
    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      dynamic response;
      if (widget.adminMode) {
        response = await supabase
            .from('jobs')
            .select()
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('jobs')
            .select()
            .neq('client_id', user.id)
            .order('created_at', ascending: false);
      }

      jobs = (response as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      await refreshAllVisiblePayments(jobs);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double? distanceToJob(JobModel job) {
    return distanceKmBetween(
      lat1: workerFilterLatitude,
      lng1: workerFilterLongitude,
      lat2: job.latitude,
      lng2: job.longitude,
    );
  }

  List<JobModel> get filteredJobs {
    final q = searchController.text.trim().toLowerCase();
    final neighborhoodQ = neighborhoodFilterController.text.trim().toLowerCase();

    final result = jobs.where((job) {
      final categoryOk =
          selectedCategory == 'Todos' || job.category == selectedCategory;

      final searchOk = q.isEmpty ||
          job.title.toLowerCase().contains(q) ||
          job.description.toLowerCase().contains(q) ||
          job.publicLocationLabel.toLowerCase().contains(q) ||
          job.category.toLowerCase().contains(q) ||
          job.subservice.toLowerCase().contains(q);

      final stateOk = job.state.trim().toUpperCase() ==
          selectedStateFilter.trim().toUpperCase();

      final cityOk = selectedCityFilter == 'Todas as cidades' ||
          job.city.trim().toLowerCase() == selectedCityFilter.trim().toLowerCase();

      final neighborhoodOk = neighborhoodQ.isEmpty ||
          job.neighborhood.toLowerCase().contains(neighborhoodQ) ||
          job.publicLocationLabel.toLowerCase().contains(neighborhoodQ);

      bool radiusOk = true;
      if (selectedRadiusKm != null) {
        final distance = distanceToJob(job);
        radiusOk = distance != null && distance <= selectedRadiusKm!;
      }

      return categoryOk && searchOk && stateOk && cityOk && neighborhoodOk && radiusOk;
    }).toList();

    if (workerFilterLatitude != null && workerFilterLongitude != null) {
      result.sort((a, b) {
        final da = distanceToJob(a);
        final db = distanceToJob(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }

    return result;
  }

  Future<bool> captureCurrentPositionForFilter() async {
    if (locatingFilter) return false;

    setState(() => locatingFilter = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ative a localização/GPS para filtrar por distância.'),
            ),
          );
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão de localização negada.'),
            ),
          );
        }
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A permissão de localização está bloqueada. Libere nas configurações do celular.',
              ),
            ),
          );
        }
        await Geolocator.openAppSettings();
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return false;
      setState(() {
        workerFilterLatitude = position.latitude;
        workerFilterLongitude = position.longitude;
      });
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui obter sua localização: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => locatingFilter = false);
    }
  }

  Future<void> setRadiusFilter(int? radius) async {
    if (radius == null) {
      setState(() => selectedRadiusKm = null);
      return;
    }

    if (workerFilterLatitude == null || workerFilterLongitude == null) {
      final ok = await captureCurrentPositionForFilter();
      if (!ok) return;
    }

    if (!mounted) return;
    setState(() => selectedRadiusKm = radius);
  }

  Future<void> useMyCity() async {
    final current = await getCurrentProfile();
    final city = current?.city?.trim() ?? '';

    if (!mounted) return;
    if (city.isEmpty || !isScCity(city)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seu perfil ainda não possui uma cidade válida de Santa Catarina.'),
        ),
      );
      return;
    }

    setState(() {
      selectedStateFilter = supportedLaunchState;
      selectedCityFilter = normalizeLaunchCity(city);
    });
  }

  void clearLocationFilters() {
    neighborhoodFilterController.clear();
    setState(() {
      selectedStateFilter = supportedLaunchState;
      selectedCityFilter = 'Todas as cidades';
      selectedRadiusKm = null;
    });
  }

  Widget buildLocationFilters() {
    final cityItems = <String>[
      'Todas as cidades',
      ...uniqueScCities(),
    ];

    final activeCount =
        (selectedCityFilter != 'Todas as cidades' ? 1 : 0) +
        (neighborhoodFilterController.text.trim().isNotEmpty ? 1 : 0) +
        (selectedRadiusKm != null ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeCount > 0 ? const Color(0xFFF4C61D) : Colors.black12,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text(
            'Filtrar por localidade',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            activeCount == 0
                ? 'Estado, cidade, bairro ou distância'
                : '$activeCount filtro(s) de localização ativo(s) • SC',
            style: const TextStyle(color: Colors.black54),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            DropdownButtonFormField<String>(
              value: selectedStateFilter,
              isExpanded: true,
              decoration: fieldDecoration('Estado'),
              items: brazilStatesLaunchOptions.map((state) {
                final uf = state.substring(0, 2);
                final locked = uf != supportedLaunchState;
                return DropdownMenuItem<String>(
                  value: uf,
                  enabled: !locked,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: locked ? Colors.black38 : Colors.black87,
                          ),
                        ),
                      ),
                      if (locked)
                        const Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Colors.black38,
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                if (value != supportedLaunchState) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Este estado será liberado em breve.'),
                    ),
                  );
                  return;
                }
                setState(() {
                  selectedStateFilter = supportedLaunchState;
                  selectedCityFilter = 'Todas as cidades';
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: cityItems.contains(selectedCityFilter)
                  ? selectedCityFilter
                  : 'Todas as cidades',
              isExpanded: true,
              decoration: fieldDecoration('Cidade/Município'),
              items: cityItems
                  .map(
                    (city) => DropdownMenuItem<String>(
                      value: city,
                      child: Text(city, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedCityFilter = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: neighborhoodFilterController,
              decoration: fieldDecoration('Bairro / região'),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Distância a partir da sua localização atual',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Qualquer distância'),
                  selected: selectedRadiusKm == null,
                  onSelected: (_) => setRadiusFilter(null),
                ),
                for (final radius in const [5, 10, 25, 50])
                  ChoiceChip(
                    label: Text('Até $radius km'),
                    selected: selectedRadiusKm == radius,
                    onSelected: (_) => setRadiusFilter(radius),
                  ),
              ],
            ),
            if (locatingFilter) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text('Obtendo sua localização...')),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: useMyCity,
                    icon: const Icon(Icons.home_work_outlined),
                    label: const Text('Minha cidade'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: activeCount == 0 ? null : clearLocationFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Limpar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'O endereço exato do cliente fica protegido antes da contratação. Para procurar jobs próximos, o app usa somente sua localização atual e as coordenadas do serviço.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openChat(JobModel job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          jobId: job.id,
          jobTitle: job.title,
        ),
      ),
    );
    await loadJobs();
  }

  Future<void> connectWorkerAndOpenChat(JobModel job) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (!widget.adminMode) {
        if (job.workerId == null || job.workerId!.isEmpty) {
          await supabase.from('jobs').update({
            'worker_id': user.id,
            if (job.status == 'open') 'status': 'proposal_sent',
          }).eq('id', job.id);
        } else if (job.workerId != user.id) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este serviço já está vinculado a outro prestador.'),
            ),
          );
          return;
        }
      }

      await loadJobs();

      if (!mounted) return;
      openChat(job);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir chat: $e')),
      );
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = filteredJobs;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adminMode
            ? 'Serviços disponíveis (ADM)'
            : 'Serviços disponíveis'),
        actions: [
          if (!widget.adminMode)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WorkerRankingPage()),
                );
              },
              icon: const Icon(Icons.leaderboard_outlined),
              tooltip: 'Ranking',
            ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadJobs,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar trabalhos...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            buildLocationFilters(),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: Stack(
                children: [
                  ListView.separated(
                    controller: categoriesScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final category = categories[index];
                      final selected = category == selectedCategory;

                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFF4C61D)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(categoryIcon(category), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (showLeftArrow)
                    Positioned(
                      left: 0,
                      top: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () async {
                          if (!categoriesScrollController.hasClients) return;
                          final nextOffset =
                              categoriesScrollController.offset - 220;
                          await categoriesScrollController.animateTo(
                            nextOffset < 0 ? 0 : nextOffset,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    top: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () async {
                        if (!categoriesScrollController.hasClients) return;
                        final nextOffset =
                            categoriesScrollController.offset + 220;
                        final maxOffset =
                            categoriesScrollController.position.maxScrollExtent;
                        await categoriesScrollController.animateTo(
                          nextOffset > maxOffset ? maxOffset : nextOffset,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${list.length} oportunidade(s) encontrada(s)',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(
                  child: Text(
                    'Nenhum trabalho encontrado com esses filtros.',
                  ),
                ),
              )
            else
              ...list.map((job) {
                final distance = distanceToJob(job);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (distance != null) ...[
                        Container(
                          margin: const EdgeInsets.only(left: 4, bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4C7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${distance.toStringAsFixed(1)} km de você',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      RequestCard(
                        job: job,
                        onChanged: loadJobs,
                        adminMode: widget.adminMode,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  bool loading = true;
  bool saving = false;
  ProfileModel? profile;
  WorkerTrustModel workerTrust = const WorkerTrustModel(workerId: '');
  WorkerIdentityEvidenceModel workerIdentityEvidence =
      const WorkerIdentityEvidenceModel(workerId: '');
  XFile? identityDocumentFile;
  XFile? identitySelfieFile;
  String identityDocumentType = 'RG/CIN';
  bool identityConsent = false;
  bool uploadingIdentity = false;
  bool identitySectionExpanded = false;
  String? profileError;
  bool womanSpaceEnabled = false;
  bool womanSpaceVisible = false;
  bool womanSpaceReceiveNotifications = true;
  bool syncingReceivingStatus = false;

  Future<void> refreshReceivingStatusAfterReturn() async {
    if (syncingReceivingStatus || profile?.role != roleWorker) return;

    syncingReceivingStatus = true;
    try {
      await syncReceivingConnectionStatus().timeout(const Duration(seconds: 10));
      final refreshed = await getCurrentProfile();
      if (!mounted || refreshed == null) return;

      setState(() {
        profile = refreshed;
      });
    } catch (_) {
      // A atualização automática é auxiliar. O botão manual continua disponível.
    } finally {
      syncingReceivingStatus = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(
        const Duration(milliseconds: 500),
        refreshReceivingStatusAfterReturn,
      );
    }
  }

  Future<void> uploadFotoPerfil() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || saving) return;

    setState(() => saving = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 80,
        requestFullMetadata: false,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('A imagem selecionada está vazia. Escolha outra foto.');
      }

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl =
          Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);

      await Supabase.instance.client
          .from('profiles')
          .update({'foto_url': publicUrl}).eq('id', user.id);

      if (!mounted) return;
      setState(() {
        profile = profile?.copyWith(fotoUrl: publicUrl);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto atualizada com sucesso.')),
      );
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao enviar foto: ${e.message}. Confira se existe um bucket público chamado avatars no Supabase Storage.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao escolher/enviar foto. Verifique a permissão de fotos do celular e tente novamente. Detalhe: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final cepController = TextEditingController();
  final addressController = TextEditingController();
  final numberController = TextEditingController();
  final complementController = TextEditingController();
  final neighborhoodController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  bool searchingCep = false;
  final specialtyController = TextEditingController();
  final workerCnpjController = TextEditingController();
  final companyLegalNameController = TextEditingController();
  final companyTradeNameController = TextEditingController();
  final companyCnpjController = TextEditingController();
  final companyResponsibleController = TextEditingController();
  final companyAddressController = TextEditingController();
  final companyNumberController = TextEditingController();
  final companyComplementController = TextEditingController();
  final companyNeighborhoodController = TextEditingController();
  final companyCityController = TextEditingController();
  final companyStateController = TextEditingController();
  final professionalCouncilNumberController = TextEditingController();
  final professionalCouncilUfController = TextEditingController();
  final professionalRqeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nameController.dispose();
    phoneController.dispose();
    cepController.dispose();
    addressController.dispose();
    numberController.dispose();
    complementController.dispose();
    neighborhoodController.dispose();
    cityController.dispose();
    stateController.dispose();
    specialtyController.dispose();
    workerCnpjController.dispose();
    companyLegalNameController.dispose();
    companyTradeNameController.dispose();
    companyCnpjController.dispose();
    companyResponsibleController.dispose();
    companyAddressController.dispose();
    companyNumberController.dispose();
    companyComplementController.dispose();
    companyNeighborhoodController.dispose();
    companyCityController.dispose();
    companyStateController.dispose();
    professionalCouncilNumberController.dispose();
    professionalCouncilUfController.dispose();
    professionalRqeController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    if (mounted) {
      setState(() {
        loading = true;
        profileError = null;
      });
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado. Saia e entre novamente.');
      }

      // Evita perfil nulo em contas recém-criadas ou sessões restauradas.
      // Se a linha já existir, essa função só completa dados básicos que faltarem.
      try {
        await ensureProfileExists().timeout(const Duration(seconds: 6));
      } catch (_) {
        // Não trava a tela por causa da criação/validação auxiliar.
        // A leitura direta abaixo ainda pode funcionar normalmente.
      }

      ProfileModel? data = await getCurrentProfile();

      // Segunda tentativa com timeout maior. O getCurrentProfile usa timeout curto
      // e retorna null em alguns casos; aqui buscamos de novo para não cair em loading infinito.
      if (data == null) {
        final response = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 8), onTimeout: () => null);

        if (response != null) {
          data = ProfileModel.fromMap(Map<String, dynamic>.from(response));
        }
      }

      if (data == null) {
        throw Exception(
          'Perfil não retornou para o usuário logado. Verifique as policies/RLS da tabela profiles e se o ID do profile é igual ao auth.uid().',
        );
      }

      if (data.role == roleWorker || data.role == roleAdmin) {
        try {
          await syncReceivingConnectionStatus().timeout(const Duration(seconds: 8));
          final refreshed = await getCurrentProfile();
          if (refreshed != null) data = refreshed;
        } catch (_) {
          // Não bloqueia o perfil se a sincronização financeira estiver indisponível.
        }
      }

      // O analyzer perde a promoção de nulabilidade de `data` após os awaits acima.
      // Neste ponto a nulidade já foi validada, então congelamos uma referência não nula.
      final resolvedProfile = data!;

      profile = resolvedProfile;
      workerTrust = resolvedProfile.role == roleWorker
          ? await loadWorkerTrust(resolvedProfile.id)
          : WorkerTrustModel(workerId: resolvedProfile.id);
      workerIdentityEvidence = resolvedProfile.role == roleWorker
          ? await loadWorkerIdentityEvidence(resolvedProfile.id)
          : WorkerIdentityEvidenceModel(workerId: resolvedProfile.id);
      if (workerIdentityEvidence.documentType == 'RG/CIN' ||
          workerIdentityEvidence.documentType == 'CNH') {
        identityDocumentType = workerIdentityEvidence.documentType;
      }
      womanSpaceEnabled = resolvedProfile.womanSpaceEnabled;
      womanSpaceVisible = resolvedProfile.womanSpaceVisible;
      womanSpaceReceiveNotifications = resolvedProfile.womanSpaceReceiveNotifications;
      nameController.text = resolvedProfile.name;
      phoneController.text = resolvedProfile.phone ?? '';
      cepController.text = resolvedProfile.cep ?? '';
      specialtyController.text = resolvedProfile.specialty ?? '';
      workerCnpjController.text = resolvedProfile.workerCnpj ?? '';
      companyLegalNameController.text = resolvedProfile.companyLegalName ?? '';
      companyTradeNameController.text = resolvedProfile.companyTradeName ?? '';
      companyCnpjController.text = resolvedProfile.companyCnpj ?? '';
      companyResponsibleController.text =
          resolvedProfile.companyResponsible ?? resolvedProfile.name;
      companyAddressController.text = resolvedProfile.companyAddress ?? '';
      companyNumberController.text = resolvedProfile.companyNumber ?? '';
      companyComplementController.text = resolvedProfile.companyComplement ?? '';
      companyNeighborhoodController.text = resolvedProfile.companyNeighborhood ?? '';
      companyCityController.text = resolvedProfile.companyCity ?? '';
      companyStateController.text = resolvedProfile.companyState ?? '';
      professionalCouncilNumberController.text = '';
      professionalCouncilUfController.text = '';
      professionalRqeController.text = '';

      if (resolvedProfile.role == roleWorker || resolvedProfile.role == roleAdmin) {
        try {
          final resumeResponse = await supabase
              .from('worker_resumes')
              .select('professional_council_number, professional_council_uf, professional_rqe')
              .eq('worker_id', resolvedProfile.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (resumeResponse != null) {
            professionalCouncilNumberController.text =
                (resumeResponse['professional_council_number'] ?? '').toString();
            professionalCouncilUfController.text =
                (resumeResponse['professional_council_uf'] ?? '').toString();
            professionalRqeController.text =
                (resumeResponse['professional_rqe'] ?? '').toString();
          }
        } catch (_) {}
      }
    } catch (e) {
      profile = null;
      profileError = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null || profile == null) return;

    setState(() => saving = true);

    try {
      await supabase.from('profiles').update({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'cep': cepController.text.trim(),
        'specialty': profile!.role == roleWorker || profile!.role == roleAdmin
            ? specialtyController.text.trim()
            : null,
        'worker_cnpj': profile!.role == roleWorker ? workerCnpjController.text.trim() : null,
        'company_legal_name': profile!.role == roleClientCompany ? companyLegalNameController.text.trim() : null,
        'company_trade_name': profile!.role == roleClientCompany ? companyTradeNameController.text.trim() : null,
        'company_cnpj': profile!.role == roleClientCompany ? companyCnpjController.text.trim() : null,
        'company_responsible': profile!.role == roleClientCompany ? companyResponsibleController.text.trim() : null,
        'company_email': profile!.role == roleClientCompany ? (supabase.auth.currentUser?.email ?? '') : null,
        'company_address': profile!.role == roleClientCompany ? companyAddressController.text.trim() : null,
        'company_number': profile!.role == roleClientCompany ? companyNumberController.text.trim() : null,
        'company_complement': profile!.role == roleClientCompany ? companyComplementController.text.trim() : null,
        'company_neighborhood': profile!.role == roleClientCompany ? companyNeighborhoodController.text.trim() : null,
        'company_city': profile!.role == roleClientCompany ? companyCityController.text.trim() : null,
        'company_state': profile!.role == roleClientCompany ? companyStateController.text.trim() : null,
        'woman_space_enabled': womanSpaceTemporarilyDisabled ? false : (profile!.role == roleClientCompany ? false : womanSpaceEnabled),
        'woman_space_visible': womanSpaceTemporarilyDisabled ? false : (profile!.role == roleClientCompany ? false : (womanSpaceEnabled && womanSpaceVisible)),
        'woman_space_receive_notifications': womanSpaceTemporarilyDisabled ? false : (profile!.role == roleClientCompany ? false : womanSpaceReceiveNotifications),
      }).eq('id', user.id);

      if (profile!.role == roleWorker || profile!.role == roleAdmin) {
        try {
          await supabase.from('worker_resumes').upsert({
            'worker_id': user.id,
            'full_name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'headline': specialtyController.text.trim(),
            'worker_cnpj': profile!.role == roleWorker ? workerCnpjController.text.trim() : null,
            'professional_council_number': professionalCouncilNumberController.text.trim(),
            'professional_council_uf': professionalCouncilUfController.text.trim().toUpperCase(),
            'professional_rqe': professionalRqeController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'worker_id');
        } catch (_) {}
      }

      await loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _identityImageExtension(XFile file) {
    final mime = (file.mimeType ?? '').toLowerCase();
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _identityImageContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> captureIdentityDocument() async {
    if (uploadingIdentity) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      setState(() => identityDocumentFile = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não consegui abrir a câmera para o documento: $e')),
      );
    }
  }

  Future<void> captureIdentitySelfie() async {
    if (uploadingIdentity) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      setState(() => identitySelfieFile = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não consegui abrir a câmera para a selfie: $e')),
      );
    }
  }

  Future<void> submitIdentityVerificationFromProfile() async {
    if (profile?.role != roleWorker || uploadingIdentity) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (identityDocumentFile == null || identitySelfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotografe o documento e tire a selfie antes de enviar.'),
        ),
      );
      return;
    }

    if (!identityConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirme a autorização de uso dos arquivos para a verificação de identidade.'),
        ),
      );
      return;
    }

    setState(() => uploadingIdentity = true);
    String? documentPath;
    String? selfiePath;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final documentExtension = _identityImageExtension(identityDocumentFile!);
      final selfieExtension = _identityImageExtension(identitySelfieFile!);

      documentPath =
          '${user.id}/document_$timestamp.$documentExtension';
      selfiePath = '${user.id}/selfie_$timestamp.$selfieExtension';

      final documentBytes = await identityDocumentFile!.readAsBytes();
      final selfieBytes = await identitySelfieFile!.readAsBytes();
      if (documentBytes.isEmpty || selfieBytes.isEmpty) {
        throw Exception('Uma das imagens está vazia. Tire as fotos novamente.');
      }

      await supabase.storage.from('identity-verification').uploadBinary(
            documentPath,
            documentBytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: _identityImageContentType(documentExtension),
            ),
          );

      await supabase.storage.from('identity-verification').uploadBinary(
            selfiePath,
            selfieBytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: _identityImageContentType(selfieExtension),
            ),
          );

      final previousDocumentPath = workerIdentityEvidence.documentPath.trim();
      final previousSelfiePath = workerIdentityEvidence.selfiePath.trim();

      await submitWorkerIdentityVerification(
        documentType: identityDocumentType,
        documentPath: documentPath,
        selfiePath: selfiePath,
      );

      final oldPaths = <String>[
        if (previousDocumentPath.isNotEmpty && previousDocumentPath != documentPath)
          previousDocumentPath,
        if (previousSelfiePath.isNotEmpty && previousSelfiePath != selfiePath)
          previousSelfiePath,
      ];
      if (oldPaths.isNotEmpty) {
        try {
          await supabase.storage.from('identity-verification').remove(oldPaths);
        } catch (_) {}
      }

      workerTrust = await loadWorkerTrust(profile!.id);
      workerIdentityEvidence = await loadWorkerIdentityEvidence(profile!.id);

      final admins = await supabase
          .from('profiles')
          .select('id')
          .eq('role', roleAdmin);

      for (final item in (admins as List)) {
        final adminId = (item['id'] ?? '').toString();
        if (adminId.isEmpty) continue;
        await createNotificationForUser(
          userId: adminId,
          title: 'Verificação de identidade pendente',
          body: '${profile!.name} enviou documento e selfie para análise.',
          referenceType: 'identity_verification',
          referenceId: profile!.id,
        );
      }

      if (!mounted) return;
      setState(() {
        identityDocumentFile = null;
        identitySelfieFile = null;
        identityConsent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento e selfie enviados com segurança para análise.'),
        ),
      );
    } catch (e) {
      final pathsToRemove = <String>[
        if (documentPath != null) documentPath,
        if (selfiePath != null) selfiePath,
      ];
      if (pathsToRemove.isNotEmpty) {
        try {
          await supabase.storage
              .from('identity-verification')
              .remove(pathsToRemove);
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar verificação de identidade: $e')),
      );
    } finally {
      if (mounted) setState(() => uploadingIdentity = false);
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  Future<void> deleteMyAccount() async {
    if (profile == null || saving) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir minha conta'),
        content: const Text(
          'Esta ação encerra sua conta PegaeFazFree e remove ou anonimiza os dados pessoais que não precisem ser mantidos para histórico de serviços, pagamentos, segurança ou obrigações aplicáveis.\n\nSe houver serviço ou pagamento ainda em andamento, a exclusão poderá ser bloqueada até a situação ser resolvida.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    final confirmationController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmação final'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para confirmar a exclusão, digite EXCLUIR no campo abaixo.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: confirmationController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Digite EXCLUIR',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () {
              final ok = confirmationController.text.trim().toUpperCase() == 'EXCLUIR';
              if (!ok) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Digite EXCLUIR para confirmar.')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir definitivamente'),
          ),
        ],
      ),
    );
    confirmationController.dispose();

    if (confirmed != true || !mounted) return;

    setState(() => saving = true);
    try {
      final data = await _invokeAuthenticatedFunction(
        'delete-account',
        body: {'confirmation': 'EXCLUIR'},
      );

      if (data['success'] == false) {
        throw Exception(data['message']?.toString() ?? 'Não foi possível excluir a conta.');
      }

      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta excluída com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir conta: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget buildWorkerSetupCard() {
    if (profile?.role != roleWorker) return const SizedBox.shrink();

    final basicChecks = <bool>[
      profile!.name.trim().isNotEmpty,
      (profile!.phone ?? '').trim().isNotEmpty,
      (profile!.specialty ?? '').trim().isNotEmpty,
      (profile!.city ?? '').trim().isNotEmpty,
      (profile!.state ?? '').trim().isNotEmpty,
    ];
    final basicDone = basicChecks.where((item) => item).length;
    final basicProgress = basicDone / basicChecks.length;
    final basicReady = basicDone == basicChecks.length;

    String identityStepLabel() {
      if (workerTrust.identityVerified) return 'Concluída';
      if (workerTrust.pending) return 'Em análise';
      if (workerTrust.status == 'rejected') return 'Revisar quando quiser';
      return 'Opcional • faça quando quiser';
    }

    String receivingStepLabel() {
      if (profile!.receivingReady) return 'Ativo';
      if (profile!.receivingUnderReview) return 'Em análise';
      if (profile!.hasReceivingAccount) return 'Continuar configuração';
      return 'Só antes de receber';
    }

    Widget stepRow({
      required IconData icon,
      required String title,
      required String badge,
      required String status,
      required bool done,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: done
                    ? Colors.green.withOpacity(0.10)
                    : const Color(0xFFFFF6CF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                done ? Icons.check_circle_outline : icon,
                size: 20,
                color: done ? Colors.green : Colors.black87,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badge == 'Essencial'
                              ? const Color(0xFFFFF0A8)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status,
                    style: TextStyle(
                      color: done ? Colors.green.shade700 : Colors.black54,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D66B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4C61D),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.rocket_launch_outlined),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      basicReady
                          ? 'Seu perfil está pronto para usar'
                          : 'Complete o essencial do seu perfil',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      basicReady
                          ? 'Você já pode buscar jobs e enviar propostas. As outras etapas podem ser feitas no momento certo.'
                          : 'Você não precisa configurar tudo de uma vez. Primeiro deixe os dados básicos prontos.',
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: basicProgress,
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      basicReady ? Colors.green : const Color(0xFFF4C61D),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$basicDone/${basicChecks.length} essenciais',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          stepRow(
            icon: Icons.person_outline,
            title: 'Dados básicos e serviço',
            badge: 'Essencial',
            status: basicReady
                ? 'Pronto para começar a usar o PegaeFazFree.'
                : 'Informe nome, telefone, especialidade, cidade e estado.',
            done: basicReady,
          ),
          stepRow(
            icon: Icons.verified_user_outlined,
            title: 'Verificar identidade',
            badge: 'Opcional',
            status: identityStepLabel(),
            done: workerTrust.identityVerified,
          ),
          stepRow(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Ativar recebimentos',
            badge: 'Para receber',
            status: receivingStepLabel(),
            done: profile!.receivingReady,
          ),
        ],
      ),
    );
  }

  Widget buildWorkerIdentityCard() {
    if (profile?.role != roleWorker) return const SizedBox.shrink();

    final verified = workerTrust.identityVerified;
    final pending = workerTrust.pending;
    final rejected = workerTrust.status == 'rejected';
    final showForm = !verified && !pending && (rejected || identitySectionExpanded);
    final statusColor = verified
        ? Colors.green
        : pending
            ? Colors.orange
            : rejected
                ? Colors.redAccent
                : Colors.black54;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: verified
              ? Colors.green.withOpacity(0.35)
              : pending
                  ? Colors.orange.withOpacity(0.35)
                  : rejected
                      ? Colors.redAccent.withOpacity(0.30)
                      : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified
                    ? Icons.verified_user
                    : pending
                        ? Icons.hourglass_top
                        : rejected
                            ? Icons.rule_folder_outlined
                            : Icons.person_search_outlined,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Identidade verificada',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (!verified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Opcional',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      workerTrust.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (verified || workerTrust.pioneerBadge) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (verified)
                  const Chip(
                    avatar: Icon(Icons.verified_user, size: 18),
                    label: Text('Identidade verificada'),
                  ),
                if (workerTrust.pioneerBadge)
                  const Chip(
                    avatar: Icon(Icons.workspace_premium_outlined, size: 18),
                    label: Text('Pioneiro PegaeFazFree'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            verified
                ? 'Sua identidade foi conferida pelo PegaeFazFree. O selo confirma a verificação de identidade, mas não representa garantia de qualidade, conduta ou resultado do serviço.'
                : pending
                    ? 'Seu documento e sua selfie foram enviados e estão em análise. Você pode continuar usando o aplicativo normalmente.'
                    : rejected
                        ? 'Sua verificação precisa de revisão. Isso não impede você de continuar usando o aplicativo. Reenvie quando quiser.'
                        : 'Esta etapa é opcional. Você pode buscar jobs e enviar propostas sem fazer isso agora. Verifique sua identidade quando quiser aumentar a confiança no seu perfil.',
            style: const TextStyle(
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          if (!verified && !pending && !rejected && !identitySectionExpanded) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => identitySectionExpanded = true),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Quero verificar minha identidade'),
              ),
            ),
          ],
          if (workerIdentityEvidence.submittedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Último envio: ${formatDate(workerIdentityEvidence.submittedAt)}',
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
          if (rejected && workerIdentityEvidence.reviewNote.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
              ),
              child: Text(
                'Orientação do PegaeFazFree: ${workerIdentityEvidence.reviewNote.trim()}',
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
              ),
            ),
          ],
          if (showForm) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0D66B)),
              ),
              child: const Text(
                'Leva poucos minutos: escolha o documento, fotografe e tire uma selfie. Você faz isso uma vez e pode continuar usando o app normalmente durante a análise.',
                style: TextStyle(
                  color: Colors.black87,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: identityDocumentType,
              decoration: fieldDecoration('Documento oficial com foto'),
              items: const [
                DropdownMenuItem(value: 'RG/CIN', child: Text('RG / Carteira de Identidade Nacional')),
                DropdownMenuItem(value: 'CNH', child: Text('CNH')),
              ],
              onChanged: uploadingIdentity
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => identityDocumentType = value);
                    },
            ),
            const SizedBox(height: 10),
            const Text(
              'Fotografe o documento com boa iluminação, sem cortes e com nome, foto e número legíveis. Depois tire uma selfie mostrando claramente o rosto.',
              style: TextStyle(color: Colors.black54, height: 1.35, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: uploadingIdentity ? null : captureIdentityDocument,
                    icon: const Icon(Icons.badge_outlined),
                    label: Text(identityDocumentFile == null ? 'Fotografar documento' : 'Refazer documento'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: uploadingIdentity ? null : captureIdentitySelfie,
                    icon: const Icon(Icons.photo_camera_front_outlined),
                    label: Text(identitySelfieFile == null ? 'Tirar selfie' : 'Refazer selfie'),
                  ),
                ),
              ],
            ),
            if (identityDocumentFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(identityDocumentFile!.path),
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (identitySelfieFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(identitySelfieFile!.path),
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: identityConsent,
              onChanged: uploadingIdentity
                  ? null
                  : (value) => setState(() => identityConsent = value == true),
              title: const Text(
                'Autorizo o uso destas imagens exclusivamente para conferência de identidade, prevenção a fraude e segurança da plataforma, conforme a Política de Privacidade.',
                style: TextStyle(fontSize: 12, height: 1.35),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: uploadingIdentity
                    ? null
                    : submitIdentityVerificationFromProfile,
                icon: uploadingIdentity
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.lock_person_outlined),
                label: Text(uploadingIdentity ? 'Enviando com segurança...' : 'Enviar para análise'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4C61D),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (!rejected) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: uploadingIdentity
                      ? null
                      : () => setState(() => identitySectionExpanded = false),
                  child: const Text('Fazer isso depois'),
                ),
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              'Documento e selfie ficam em armazenamento privado. Clientes e outros prestadores não conseguem visualizar esses arquivos.',
              style: TextStyle(fontSize: 11, color: Colors.black45, height: 1.35),
            ),
          ],
          if (workerTrust.pioneerBadge) ...[
            const SizedBox(height: 8),
            const Text(
              'O selo Pioneiro PegaeFazFree é um reconhecimento simbólico pela participação na fase inicial da plataforma. Ele não concede participação societária, direito a lucros, propriedade da empresa ou poder de representação.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildWorkerReceivingCard() {
    if (profile?.role != roleWorker) return const SizedBox.shrink();

    final ready = profile!.receivingReady;
    final underReview = profile!.receivingUnderReview;
    final connected = profile!.hasReceivingAccount;
    final statusColor = ready
        ? Colors.green
        : underReview
            ? Colors.orange
            : connected
                ? Colors.orange
                : Colors.black54;

    final description = ready
        ? 'Pronto. Você pode receber os repasses dos serviços pagos pela plataforma.'
        : underReview
            ? 'Sua conta de recebimento está conectada e em análise. Continue usando o aplicativo normalmente enquanto o provedor conclui a análise.'
            : connected
                ? 'Sua conta já foi criada. Termine a configuração antes de precisar receber um pagamento pela plataforma.'
                : 'Você não precisa configurar isso agora. Já pode buscar jobs, conversar e enviar propostas. Ative os recebimentos somente antes de receber pagamentos pelo PegaeFazFree.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ready
              ? Colors.green.withOpacity(0.35)
              : underReview || connected
                  ? Colors.orange.withOpacity(0.30)
                  : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready
                    ? Icons.account_balance_wallet
                    : Icons.account_balance_wallet_outlined,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recebimentos pela plataforma',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile!.receivingStatusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!ready)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Quando precisar',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (profile!.stripeDetailsSubmitted &&
                    profile!.hasReceivingAccount) {
                  openReceivingAccount(context);
                } else {
                  connectForReceiving(context);
                }
              },
              icon: Icon(
                connected
                    ? Icons.open_in_new
                    : Icons.account_balance_wallet_outlined,
              ),
              label: Text(
                ready
                    ? 'Abrir conta de recebimento'
                    : connected
                        ? profile!.receivingButtonLabel
                        : 'Configurar recebimentos',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ready
                    ? Colors.green
                    : underReview
                        ? Colors.orange
                        : const Color(0xFFF4C61D),
                foregroundColor:
                    ready || underReview ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (connected) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        try {
                          await syncReceivingConnectionStatus();
                          await loadProfile();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  profile?.receivingStatusLabel == null
                                      ? 'Status de recebimento atualizado.'
                                      : 'Recebimentos: ${profile!.receivingStatusLabel}.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao atualizar recebimentos: $e'),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                icon: const Icon(Icons.sync),
                label: const Text('Atualizar status'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 58,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Não foi possível carregar seu perfil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O cadastro existe, mas o app não conseguiu ler os dados dessa conta agora. Toque em tentar novamente ou saia e entre de novo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
                if (profileError != null && profileError!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                    ),
                    child: SelectableText(
                      profileError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4C61D),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair e entrar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final roleLabel = roleLabelPt(profile!.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
Stack(
  alignment: Alignment.center,
  children: [
    CircleAvatar(
      radius: 42,
backgroundImage: profile?.fotoUrl != null
    ? NetworkImage(profile!.fotoUrl!)
    : const NetworkImage('https://i.pravatar.cc/300'),
      backgroundColor: const Color(0xFFF3FEEB),
      child: profile?.fotoUrl == null
          ? const Icon(Icons.person, size: 40, color: Colors.black54)
          : null,
    ),
    Positioned(
      bottom: 0,
      right: 0,
      child: GestureDetector(
        onTap: uploadFotoPerfil,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(6),
          child: const Icon(
            Icons.camera_alt,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    ),
  ],
),
                const SizedBox(height: 12),
                Text(
                  roleLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  supabase.auth.currentUser?.email ?? '',
                  style: const TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<Map<String, dynamic>>(
            future: loadProfileMetrics(profile!.id, role: profile!.role),
            builder: (context, snapshot) {
              final metrics = snapshot.data ?? const {};
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumo do perfil',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ProfileMetricChip(
                          label: 'Avaliação média',
                          value: (metrics['ratingAverage'] ?? '0.0').toString(),
                          icon: Icons.star,
                        ),
                        _ProfileMetricChip(
                          label: 'Avaliações',
                          value: (metrics['ratingCount'] ?? 0).toString(),
                          icon: Icons.rate_review_outlined,
                        ),
                        _ProfileMetricChip(
                          label: profile!.role == roleWorker ? 'Serviços realizados' : 'Serviços concluídos',
                          value: (metrics['completedServices'] ?? metrics['jobsCount'] ?? 0).toString(),
                          icon: Icons.work_outline,
                        ),
                        _ProfileMetricChip(
                          label: 'Membro desde',
                          value: (metrics['memberSince'] ?? 'Não informado').toString(),
                          icon: Icons.calendar_today_outlined,
                        ),
                        if (profile!.role == roleWorker)
                          _ProfileMetricChip(
                            label: 'Recebimentos',
                            value: profile!.receivingStatusLabel,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                      ],
                    ),
                    if (profile!.role == roleWorker || profile!.role == roleAdmin) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Especialidade: ${profile!.specialty?.isNotEmpty == true ? profile!.specialty! : 'não informada'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: supabase.from('worker_resumes').select('professional_council_type,professional_council_number,professional_council_uf,professional_validated,validated_seal,professional_rqe').eq('worker_id', profile!.id).maybeSingle(),
                        builder: (context, snap) {
                          final data = snap.data;
                          if (data == null || (data['professional_council_type'] ?? '').toString().isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final validated = data['professional_validated'] == true;
                          final type = (data['professional_council_type'] ?? '').toString();
                          final number = (data['professional_council_number'] ?? '').toString();
                          final uf = (data['professional_council_uf'] ?? '').toString();
                          final rqe = (data['professional_rqe'] ?? '').toString();
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: validated ? const Color(0xFFE8F8EA) : const Color(0xFFFFF4D6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$type: $number/$uf', style: const TextStyle(fontWeight: FontWeight.w800)),
                                if (rqe.isNotEmpty) Text('RQE: $rqe', style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text(validated ? 'Registro profissional verificado pelo ADM' : '$type pendente de verificação do ADM', style: TextStyle(fontWeight: FontWeight.w800, color: validated ? Colors.green : Colors.orange)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          if (profile!.role == roleWorker) ...[
            buildWorkerSetupCard(),
            const SizedBox(height: 18),
            buildWorkerIdentityCard(),
            const SizedBox(height: 18),
          ],
          FutureBuilder<double>(
            future: getEffectivePlatformFeePercent(),
            builder: (context, snapshot) {
              final fee = snapshot.data ?? 10;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.percent, color: Colors.black87),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Taxa atual da plataforma: ${fee.toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          InputField(controller: nameController, hint: 'Nome'),
          const SizedBox(height: 12),
          InputField(
            controller: phoneController,
            hint: 'Telefone',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          InputField(
            controller: cepController,
            hint: 'CEP',
            keyboardType: TextInputType.number,
          ),
          if (profile!.role == roleWorker || profile!.role == roleAdmin) ...[
            const SizedBox(height: 12),
            InputField(
              controller: specialtyController,
              hint: profile!.role == roleAdmin
                  ? 'Área / observação administrativa'
                  : 'Especialidade principal',
            ),
            if (profile!.role == roleWorker) ...[
              const SizedBox(height: 12),
              InputField(
                controller: workerCnpjController,
                hint: 'CNPJ do prestador (opcional)',
                keyboardType: TextInputType.number,
              ),
            ],
          ],
          if (profile!.role == roleClientCompany) ...[
            const SizedBox(height: 12),
            InputField(controller: companyLegalNameController, hint: 'Razão social'),
            const SizedBox(height: 12),
            InputField(controller: companyTradeNameController, hint: 'Nome fantasia'),
            const SizedBox(height: 12),
            InputField(controller: companyCnpjController, hint: 'CNPJ'),
            const SizedBox(height: 12),
            InputField(controller: companyResponsibleController, hint: 'Responsável pela conta'),
            const SizedBox(height: 12),
            InputField(controller: companyAddressController, hint: 'Endereço empresarial'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: InputField(controller: companyNumberController, hint: 'Número')),
                const SizedBox(width: 12),
                Expanded(child: InputField(controller: companyComplementController, hint: 'Complemento')),
              ],
            ),
            const SizedBox(height: 12),
            InputField(controller: companyNeighborhoodController, hint: 'Bairro'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: InputField(controller: companyCityController, hint: 'Cidade')),
                const SizedBox(width: 12),
                Expanded(child: InputField(controller: companyStateController, hint: 'UF')),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                profile!.companyVerified ? 'Empresa verificada' : 'Empresa pendente de verificação',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: profile!.companyVerified ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
          if (!womanSpaceTemporarilyDisabled && profile!.role != roleClientCompany) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: womanSpaceEnabled ? const Color(0xFFE91E63) : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFFFE1EF),
                        child: Icon(Icons.female, color: Color(0xFFE91E63)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Espaço Mulher',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              womanSpaceEnabled
                                  ? 'Seu acesso está ativo. Você pode entrar e ajustar seu perfil.'
                                  : 'Ative para acessar o ambiente opcional do Espaço Mulher.',
                              style: const TextStyle(color: Colors.black54, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ativar Espaço Mulher'),
                    subtitle: const Text('Essa área é opcional e pode ser desativada quando quiser.'),
                    value: womanSpaceEnabled,
                    onChanged: saving
                        ? null
                        : (v) {
                            setState(() {
                              womanSpaceEnabled = v;
                              if (!v) womanSpaceVisible = false;
                            });
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar meu perfil no Espaço Mulher'),
                    value: womanSpaceEnabled && womanSpaceVisible,
                    onChanged: saving || !womanSpaceEnabled
                        ? null
                        : (v) => setState(() => womanSpaceVisible = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Receber notificações do Espaço Mulher'),
                    value: womanSpaceReceiveNotifications,
                    onChanged: saving
                        ? null
                        : (v) => setState(() => womanSpaceReceiveNotifications = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: womanSpaceEnabled
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WomanSpacePage(profile: profile!),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('Entrar no Espaço Mulher'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Depois de alterar essas opções, toque em “Salvar perfil”.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: saving ? null : saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4C61D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: saving
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Salvar perfil',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (profile!.role == roleWorker) ...[
            buildWorkerReceivingCard(),
            const SizedBox(height: 18),
          ],
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de Privacidade'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalTextPage(
                          title: 'Política de Privacidade',
                          body: privacyText,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Termos de Uso'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalTextPage(
                          title: 'Termos de Uso',
                          body: termsText,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Proteção do Usuário'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalTextPage(
                          title: 'Proteção do Usuário',
                          body: protectionText,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
          if (profile!.role != roleAdmin && !isPrivilegedAdminEmail(supabase.auth.currentUser?.email)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: saving ? null : deleteMyAccount,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Excluir minha conta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class WomanSpacePage extends StatelessWidget {
  final ProfileModel profile;

  const WomanSpacePage({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espaço Mulher'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE1EF), Color(0xFFF4C61D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.female, color: Color(0xFFE91E63), size: 34),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bem-vinda, ${profile.name}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Um espaço opcional dentro do PegaeFazFree para apoiar, conectar e dar mais visibilidade para mulheres na plataforma.',
                  style: TextStyle(height: 1.35, color: Colors.black87, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu status no Espaço Mulher',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _WomanStatusLine(
                  icon: Icons.check_circle_outline,
                  label: 'Acesso',
                  value: womanSpaceTemporarilyDisabled ? 'Oculto para lançamento' : (profile.womanSpaceEnabled ? 'Ativo' : 'Desativado'),
                ),
                _WomanStatusLine(
                  icon: Icons.visibility_outlined,
                  label: 'Perfil visível',
                  value: womanSpaceTemporarilyDisabled ? 'Não' : (profile.womanSpaceVisible ? 'Sim' : 'Não'),
                ),
                _WomanStatusLine(
                  icon: Icons.notifications_active_outlined,
                  label: 'Notificações',
                  value: womanSpaceTemporarilyDisabled ? 'Desativadas' : (profile.womanSpaceReceiveNotifications ? 'Ativas' : 'Desativadas'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O que vai entrar aqui',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 10),
                Text('• Serviços e oportunidades com foco em segurança e acolhimento.'),
                SizedBox(height: 6),
                Text('• Destaque para prestadoras que escolherem aparecer nesse espaço.'),
                SizedBox(height: 6),
                Text('• Conteúdos, avisos e suporte específico para mulheres.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Para alterar ativação, visibilidade ou notificações, volte ao Perfil, ajuste as opções do Espaço Mulher e toque em “Salvar perfil”.',
            style: TextStyle(color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _WomanStatusLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WomanStatusLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE91E63)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}


class ActiveAnnouncementBanner extends StatefulWidget {
  const ActiveAnnouncementBanner({super.key});

  @override
  State<ActiveAnnouncementBanner> createState() => _ActiveAnnouncementBannerState();
}

class _ActiveAnnouncementBannerState extends State<ActiveAnnouncementBanner> {
  late final Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = getCurrentUserRole();
  }

  bool _canShowForRole(String audience, String role) {
    final normalizedAudience = audience.trim().toLowerCase();
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedAudience == 'all') return true;
    if (normalizedAudience == roleClient && normalizedRole == roleClient) return true;
    if (normalizedAudience == roleClientCompany && normalizedRole == roleClientCompany) return true;
    if (normalizedAudience == roleWorker && normalizedRole == roleWorker) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, roleSnapshot) {
        if (!roleSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final role = roleSnapshot.data!;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('app_announcements')
              .stream(primaryKey: ['id'])
              .eq('is_active', true)
              .order('updated_at', ascending: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final items = snapshot.data!
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            Map<String, dynamic>? found;
            for (final item in items) {
              final audience = (item['audience'] ?? 'all').toString();
              final message = (item['message'] ?? '').toString().trim();

              if (message.isEmpty) continue;
              if (_canShowForRole(audience, role)) {
                found = item;
                break;
              }
            }

            if (found == null) {
              return const SizedBox.shrink();
            }

            final message = (found['message'] ?? '').toString().trim();
            if (message.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: Colors.black),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        message,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final titleController = TextEditingController();
  final messageController = TextEditingController();

  bool loading = true;
  bool active = true;
  String audience = 'all';
  List<Map<String, dynamic>> announcements = [];

  @override
  void initState() {
    super.initState();
    loadAnnouncements();
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> loadAnnouncements() async {
    setState(() => loading = true);
    try {
      final response = await supabase
          .from('app_announcements')
          .select()
          .order('updated_at', ascending: false);
      announcements = (response as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      announcements = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveAnnouncement() async {
    final title = titleController.text.trim();
    final message = messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha título e mensagem.')),
      );
      return;
    }

    try {
      await supabase.from('app_announcements').insert({
        'title': title,
        'message': message,
        'is_active': active,
        'audience': audience,
        'updated_at': DateTime.now().toIso8601String(),
      });

      titleController.clear();
      messageController.clear();

      if (mounted) {
        setState(() {
          active = true;
          audience = 'all';
        });
      }

      await loadAnnouncements();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensagem global salva.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar aviso: $e')),
      );
    }
  }

  Future<void> toggleAnnouncement(Map<String, dynamic> item, bool value) async {
    await supabase
        .from('app_announcements')
        .update({
          'is_active': value,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', item['id']);

    await loadAnnouncements();
  }

  Future<void> deleteAnnouncement(String id) async {
    await supabase.from('app_announcements').delete().eq('id', id);
    await loadAnnouncements();
  }

  String audienceLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case roleClient:
        return 'Cliente';
      case roleClientCompany:
        return 'Cliente empresa';
      case roleWorker:
        return 'Prestador';
      default:
        return 'Todos';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensagem global do app')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Criar aviso rolante',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputField(
                        controller: titleController,
                        hint: 'Título do aviso',
                      ),
                      const SizedBox(height: 12),
                      InputField(
                        controller: messageController,
                        hint: 'Mensagem para os usuários',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: audience,
                        decoration: fieldDecoration('Público do aviso'),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Todos'),
                          ),
                          DropdownMenuItem(
                            value: roleClient,
                            child: Text('Somente clientes'),
                          ),
                          DropdownMenuItem(
                            value: roleClientCompany,
                            child: Text('Somente clientes empresa'),
                          ),
                          DropdownMenuItem(
                            value: roleWorker,
                            child: Text('Somente prestadores'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => audience = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: active,
                        onChanged: (v) => setState(() => active = v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ativar assim que salvar'),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: saveAnnouncement,
                          icon: const Icon(Icons.send),
                          label: const Text('Salvar e publicar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF4C61D),
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Histórico de mensagens',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 10),
                if (announcements.isEmpty)
                  const Text('Nenhuma mensagem criada ainda.')
                else
                  ...announcements.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['title'] ?? 'Aviso').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text((item['message'] ?? '').toString()),
                          const SizedBox(height: 8),
                          Text(
                            'Público: ${audienceLabel((item['audience'] ?? 'all').toString())}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (item['is_active'] == true)
                                      ? 'Ativo no app'
                                      : 'Inativo',
                                  style: TextStyle(
                                    color: (item['is_active'] == true)
                                        ? Colors.green
                                        : Colors.black54,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch(
                                value: item['is_active'] == true,
                                onChanged: (v) => toggleAnnouncement(item, v),
                              ),
                              IconButton(
                                onPressed: () => deleteAnnouncement(
                                  (item['id'] ?? '').toString(),
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}


class PffTrustMetrics {
  final double ratingAverage;
  final int ratingCount;
  final int completedServices;
  final int publishedServices;
  final int contractedServices;
  final int inProgressServices;
  final int totalServices;
  final String memberSince;

  const PffTrustMetrics({
    required this.ratingAverage,
    required this.ratingCount,
    required this.completedServices,
    required this.publishedServices,
    required this.contractedServices,
    required this.inProgressServices,
    required this.totalServices,
    required this.memberSince,
  });

  Map<String, dynamic> toMap() {
    return {
      'ratingAverage': ratingAverage.toStringAsFixed(1),
      'ratingCount': ratingCount,
      'completedServices': completedServices,
      'publishedServices': publishedServices,
      'contractedServices': contractedServices,
      'inProgressServices': inProgressServices,
      'totalServices': totalServices,
      'memberSince': memberSince,
      'jobsCount': totalServices,
    };
  }
}

class PffFinancialMetrics {
  final double today;
  final double month;
  final double year;
  final double total;
  final int completed;
  final int inProgress;
  final int proposalsSent;
  final int proposalsAccepted;
  final List<double> monthlyValues;
  final List<String> monthlyLabels;

  const PffFinancialMetrics({
    required this.today,
    required this.month,
    required this.year,
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.proposalsSent,
    required this.proposalsAccepted,
    required this.monthlyValues,
    required this.monthlyLabels,
  });
}

DateTime? parseFlexibleDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

bool sameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String monthShortPt(int month) {
  const labels = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
  if (month < 1 || month > 12) return '';
  return labels[month - 1];
}

List<String> lastSixMonthLabels() {
  final now = DateTime.now();
  return List.generate(6, (index) {
    final d = DateTime(now.year, now.month - (5 - index), 1);
    return monthShortPt(d.month);
  });
}

int monthIndexInLastSix(DateTime? date) {
  if (date == null) return -1;
  final now = DateTime.now();
  for (var i = 0; i < 6; i++) {
    final d = DateTime(now.year, now.month - (5 - i), 1);
    if (date.year == d.year && date.month == d.month) return i;
  }
  return -1;
}

String memberSinceLabel(DateTime? createdAt) {
  if (createdAt == null) return 'Não informado';
  return createdAt.year.toString();
}

Future<PffTrustMetrics> loadUserTrustMetrics(String userId, {String? role}) async {
  double avg = 0;
  int ratingCount = 0;
  int completedServices = 0;
  int publishedServices = 0;
  int contractedServices = 0;
  int inProgressServices = 0;
  int totalServices = 0;
  String memberSince = 'Não informado';

  try {
    final reviews = await supabase.from('reviews').select('rating').eq('reviewed_id', userId);
    final reviewList = (reviews as List).map((e) => Map<String, dynamic>.from(e)).toList();
    ratingCount = reviewList.length;
    if (ratingCount > 0) {
      avg = reviewList.fold<double>(
            0,
            (sum, item) => sum + ((item['rating'] ?? 0) as num).toDouble(),
          ) /
          ratingCount;
    }
  } catch (_) {}

  try {
    final profileResponse = await supabase
        .from('profiles')
        .select('created_at')
        .eq('id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 4), onTimeout: () => null);
    if (profileResponse != null) {
      memberSince = memberSinceLabel(parseFlexibleDate(profileResponse['created_at']));
    }
  } catch (_) {}

  try {
    final normalizedRole = (role ?? '').trim().toLowerCase();
    if (normalizedRole == roleWorker) {
      final jobs = await supabase.from('jobs').select('id,status').eq('worker_id', userId);
      final list = (jobs as List).map((e) => Map<String, dynamic>.from(e)).toList();
      completedServices = list.where((e) => (e['status'] ?? '').toString() == 'done').length;
      inProgressServices = list.where((e) {
        final status = (e['status'] ?? '').toString();
        return status == 'proposal_sent' || status == 'in_progress';
      }).length;
      totalServices = completedServices;
    } else {
      final jobs = await supabase.from('jobs').select('id,status').eq('client_id', userId);
      final list = (jobs as List).map((e) => Map<String, dynamic>.from(e)).toList();
      publishedServices = list.length;
      contractedServices = list.where((e) => (e['status'] ?? '').toString() == 'done').length;
      completedServices = contractedServices;
      inProgressServices = list.where((e) {
        final status = (e['status'] ?? '').toString();
        return status == 'proposal_sent' || status == 'in_progress';
      }).length;
      totalServices = contractedServices;
    }
  } catch (_) {}

  return PffTrustMetrics(
    ratingAverage: avg,
    ratingCount: ratingCount,
    completedServices: completedServices,
    publishedServices: publishedServices,
    contractedServices: contractedServices,
    inProgressServices: inProgressServices,
    totalServices: totalServices,
    memberSince: memberSince,
  );
}

Future<Map<String, dynamic>> loadProfileMetrics(String userId, {String? role}) async {
  final metrics = await loadUserTrustMetrics(userId, role: role);
  return metrics.toMap();
}

Future<PffFinancialMetrics> loadWorkerFinancialMetrics(String workerId) async {
  final now = DateTime.now();
  final monthlyValues = List<double>.filled(6, 0);
  final monthlyLabels = lastSixMonthLabels();
  double today = 0;
  double month = 0;
  double year = 0;
  double total = 0;
  int completed = 0;
  int inProgress = 0;
  int proposalsSent = 0;
  int proposalsAccepted = 0;

  try {
    final jobsResponse = await supabase
        .from('jobs')
        .select('id,status,price,created_at,concluded_at,payment_status')
        .eq('worker_id', workerId);

    final jobs = (jobsResponse as List).map((e) => Map<String, dynamic>.from(e)).toList();
    for (final job in jobs) {
      final status = (job['status'] ?? '').toString();
      if (status == 'proposal_sent' || status == 'in_progress') inProgress++;
      if (status != 'done') continue;
      completed++;
      final value = ((job['price'] ?? 0) as num).toDouble();
      final when = parseFlexibleDate(job['concluded_at']) ?? parseFlexibleDate(job['created_at']);
      today += sameDay(when, now) ? value : 0;
      month += when != null && when.year == now.year && when.month == now.month ? value : 0;
      year += when != null && when.year == now.year ? value : 0;
      total += value;
      final index = monthIndexInLastSix(when);
      if (index >= 0) monthlyValues[index] += value;
    }
  } catch (_) {}

  try {
    final proposalsResponse = await supabase
        .from('proposals')
        .select('id,status')
        .eq('worker_id', workerId);
    final proposals = (proposalsResponse as List).map((e) => Map<String, dynamic>.from(e)).toList();
    proposalsSent = proposals.length;
    proposalsAccepted = proposals.where((e) => (e['status'] ?? '').toString() == 'accepted').length;
  } catch (_) {}

  return PffFinancialMetrics(
    today: today,
    month: month,
    year: year,
    total: total,
    completed: completed,
    inProgress: inProgress,
    proposalsSent: proposalsSent,
    proposalsAccepted: proposalsAccepted,
    monthlyValues: monthlyValues,
    monthlyLabels: monthlyLabels,
  );
}

class PffMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? backgroundColor;

  const PffMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class PffDashboardBarChart extends StatelessWidget {
  final String title;
  final List<String> labels;
  final List<double> values;
  final bool moneyValues;

  const PffDashboardBarChart({
    super.key,
    required this.title,
    required this.labels,
    required this.values,
    this.moneyValues = false,
  });

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (index) {
                final value = values[index];
                final factor = max <= 0 ? 0.03 : (value / max).clamp(0.03, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          moneyValues ? money(value) : value.toStringAsFixed(0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 120 * factor,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF4C61D), Color(0xFFE4A60B)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels.length > index ? labels[index] : '',
                          style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class PffActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const PffActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: const Color(0xFFF4C61D), child: Icon(icon, color: Colors.black)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54, height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}


class WorkerRankingEntry {
  final String userId;
  final String name;
  final String specialty;
  final double averageRating;
  final int reviewsCount;
  final int completedJobs;

  const WorkerRankingEntry({
    required this.userId,
    required this.name,
    required this.specialty,
    required this.averageRating,
    required this.reviewsCount,
    required this.completedJobs,
  });

  double get score => (averageRating * 0.7) + (reviewsCount * 0.1) + (completedJobs * 0.2);
}

Future<List<WorkerRankingEntry>> loadWorkerRanking() async {
  try {
    final profilesResponse = await supabase
        .from('profiles')
        .select('id,name,specialty,role')
        .eq('role', 'worker');

    final profiles = (profilesResponse as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final List<WorkerRankingEntry> ranking = [];
    for (final profile in profiles) {
      final id = (profile['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating')
          .eq('reviewed_id', id);
      final reviews = (reviewsResponse as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final completedJobsResponse = await supabase
          .from('jobs')
          .select('id')
          .eq('worker_id', id)
          .eq('status', 'done');
      final completedJobs = (completedJobsResponse as List).length;

      final reviewsCount = reviews.length;
      final averageRating = reviewsCount == 0
          ? 0.0
          : reviews.fold<double>(
                0,
                (sum, item) => sum + ((item['rating'] ?? 0) as num).toDouble(),
              ) /
              reviewsCount;

      ranking.add(
        WorkerRankingEntry(
          userId: id,
          name: (profile['name'] ?? 'Prestador').toString(),
          specialty: (profile['specialty'] ?? 'Especialidade não informada').toString(),
          averageRating: averageRating,
          reviewsCount: reviewsCount,
          completedJobs: completedJobs,
        ),
      );
    }

    ranking.sort((a, b) => b.score.compareTo(a.score));
    return ranking;
  } catch (_) {
    return [];
  }
}

class WorkerRankingPage extends StatefulWidget {
  const WorkerRankingPage({super.key});

  @override
  State<WorkerRankingPage> createState() => _WorkerRankingPageState();
}

class _WorkerRankingPageState extends State<WorkerRankingPage> {
  bool loading = true;
  List<WorkerRankingEntry> ranking = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    ranking = await loadWorkerRanking();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking de prestadores'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ranking.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Ainda não há dados suficientes para montar o ranking.'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: ranking.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final item = ranking[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFF4C61D),
                              child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Text(item.specialty, style: const TextStyle(color: Colors.black54)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _InfoTag(icon: Icons.star, text: item.averageRating.toStringAsFixed(1)),
                                      _InfoTag(icon: Icons.rate_review_outlined, text: '${item.reviewsCount} avaliações'),
                                      _InfoTag(icon: Icons.verified_outlined, text: '${item.completedJobs} concluídos'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class PublicProfilePage extends StatefulWidget {
  final String profileId;

  const PublicProfilePage({
    super.key,
    required this.profileId,
  });

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool loading = true;
  ProfileModel? profile;
  Map<String, dynamic> metrics = const {};
  Map<String, dynamic>? resume;
  WorkerTrustModel workerTrust = const WorkerTrustModel(workerId: '');
  List<ReviewModel> publicReviews = [];
  String? errorText;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final response = await supabase
          .from('profiles')
          .select(
            'id,name,role,city,state,specialty,worker_cnpj,foto_url,'
            'company_legal_name,company_trade_name,company_cnpj,company_responsible,'
            'company_city,company_state,company_verified',
          )
          .eq('id', widget.profileId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);

      if (response == null) {
        throw Exception('Perfil não encontrado ou sem permissão de leitura.');
      }

      final loadedProfile = ProfileModel.fromMap(Map<String, dynamic>.from(response));
      final loadedMetrics = await loadProfileMetrics(widget.profileId, role: loadedProfile.role);
      Map<String, dynamic>? loadedResume;
      WorkerTrustModel loadedTrust = WorkerTrustModel(workerId: widget.profileId);

      if (loadedProfile.role == roleWorker || loadedProfile.role == roleAdmin) {
        try {
          final resumeResponse = await supabase
              .from('worker_resumes')
              .select(
                'worker_id,worker_cnpj,professional_council_type,'
                'professional_council_number,professional_council_uf,'
                'professional_validated',
              )
              .eq('worker_id', widget.profileId)
              .maybeSingle()
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (resumeResponse != null) {
            loadedResume = Map<String, dynamic>.from(resumeResponse);
          }
        } catch (_) {}
      }

      if (loadedProfile.role == roleWorker) {
        loadedTrust = await loadWorkerTrust(widget.profileId);
      }

      List<ReviewModel> loadedReviews = [];
      try {
        final reviewsResponse = await supabase
            .from('reviews')
            .select()
            .eq('reviewed_id', widget.profileId)
            .order('created_at', ascending: false)
            .limit(10);
        loadedReviews = (reviewsResponse as List)
            .map((e) => ReviewModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        profile = loadedProfile;
        metrics = loadedMetrics;
        resume = loadedResume;
        workerTrust = loadedTrust;
        publicReviews = loadedReviews;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = e.toString();
        loading = false;
      });
    }
  }

  Future<void> reportProfile() async {
    final loaded = profile;
    if (loaded == null) return;
    if (loaded.id == supabase.auth.currentUser?.id) return;

    final profileMap = <String, dynamic>{
      'id': loaded.id,
      'name': loaded.name,
      'role': loaded.role,
      'company_trade_name': loaded.companyTradeName,
      'company_legal_name': loaded.companyLegalName,
      'company_responsible': loaded.companyResponsible,
    };

    await showUserReportDialog(
      context,
      reportedUserId: loaded.id,
      reportedDisplayName: displayProfileNameFromMap(profileMap),
      source: 'profile',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorText ?? 'Não foi possível carregar o perfil.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
          ),
        ),
      );
    }

    final profileMap = <String, dynamic>{
      'id': profile!.id,
      'name': profile!.name,
      'role': profile!.role,
      'email': profile!.id == supabase.auth.currentUser?.id ? supabase.auth.currentUser?.email : null,
      'company_trade_name': profile!.companyTradeName,
      'company_legal_name': profile!.companyLegalName,
      'company_responsible': profile!.companyResponsible,
    };
    final displayName = displayProfileNameFromMap(profileMap);
    final currentEmail = supabase.auth.currentUser?.email;
    final isOfficial = profile!.role == roleAdmin || (profile!.id == supabase.auth.currentUser?.id && isPrivilegedAdminEmail(currentEmail));
    final professionalCouncilType = (resume?['professional_council_type'] ?? '').toString();
    final professionalCouncilNumber = (resume?['professional_council_number'] ?? '').toString();
    final professionalCouncilUf = (resume?['professional_council_uf'] ?? '').toString();
    final professionalValidated = resume?['professional_validated'] == true;
    final workerCnpj = (profile!.workerCnpj ?? resume?['worker_cnpj'] ?? '').toString().trim();

    final isOwnProfile = profile!.id == supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil público'),
        actions: [
          if (!isOwnProfile && !isOfficial)
            IconButton(
              onPressed: reportProfile,
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Denunciar usuário',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFFF4C61D),
                    backgroundImage: (profile!.fotoUrl ?? '').trim().isNotEmpty ? NetworkImage(profile!.fotoUrl!) : null,
                    child: (profile!.fotoUrl ?? '').trim().isEmpty
                        ? Text(displayProfileInitial(displayName), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (isOfficial) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_user, size: 20, color: Colors.black87),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(roleLabelPt(profile!.role), style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                  if (profile!.role == roleWorker &&
                      (workerTrust.identityVerified || workerTrust.pioneerBadge)) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (workerTrust.identityVerified)
                          const Chip(
                            avatar: Icon(Icons.verified_user, size: 18),
                            label: Text('Identidade verificada'),
                          ),
                        if (workerTrust.pioneerBadge)
                          const Chip(
                            avatar: Icon(Icons.workspace_premium_outlined, size: 18),
                            label: Text('Pioneiro PegaeFazFree'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ProfileMetricChip(
                    label: 'Avaliação média',
                    value: (metrics['ratingAverage'] ?? '0.0').toString(),
                    icon: Icons.star,
                  ),
                  _ProfileMetricChip(
                    label: 'Avaliações',
                    value: (metrics['ratingCount'] ?? 0).toString(),
                    icon: Icons.rate_review_outlined,
                  ),
                  if (profile!.role == roleWorker) ...[
                    _ProfileMetricChip(
                      label: 'Serviços realizados',
                      value: (metrics['completedServices'] ?? 0).toString(),
                      icon: Icons.handyman_outlined,
                    ),
                    _ProfileMetricChip(
                      label: 'Em andamento',
                      value: (metrics['inProgressServices'] ?? 0).toString(),
                      icon: Icons.timelapse_outlined,
                    ),
                  ] else ...[
                    _ProfileMetricChip(
                      label: 'Serviços pedidos',
                      value: (metrics['publishedServices'] ?? 0).toString(),
                      icon: Icons.post_add_outlined,
                    ),
                    _ProfileMetricChip(
                      label: 'Serviços concluídos',
                      value: (metrics['contractedServices'] ?? metrics['completedServices'] ?? 0).toString(),
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                  _ProfileMetricChip(
                    label: 'Membro desde',
                    value: (metrics['memberSince'] ?? 'Não informado').toString(),
                    icon: Icons.calendar_today_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if ((profile!.specialty ?? '').trim().isNotEmpty)
                    Text('Especialidade: ${profile!.specialty}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if ((profile!.city ?? '').trim().isNotEmpty || (profile!.state ?? '').trim().isNotEmpty)
                    Text('Local: ${(profile!.city ?? '').trim()} ${(profile!.state ?? '').trim()}'.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (profile!.role == roleClientCompany) ...[
                    if ((profile!.companyTradeName ?? '').trim().isNotEmpty) Text('Nome fantasia: ${profile!.companyTradeName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if ((profile!.companyLegalName ?? '').trim().isNotEmpty) Text('Razão social: ${profile!.companyLegalName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if ((profile!.companyCnpj ?? '').trim().isNotEmpty) Text('CNPJ: ${profile!.companyCnpj}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                  if (workerCnpj.isNotEmpty && profile!.role == roleWorker)
                    Text('CNPJ profissional: $workerCnpj', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (professionalCouncilType.isNotEmpty && professionalCouncilNumber.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: professionalValidated ? const Color(0xFFE8F8EA) : const Color(0xFFFFF4D6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        professionalValidated
                            ? '$professionalCouncilType verificado: $professionalCouncilNumber/$professionalCouncilUf'
                            : '$professionalCouncilType pendente de verificação: $professionalCouncilNumber/$professionalCouncilUf',
                        style: TextStyle(fontWeight: FontWeight.w800, color: professionalValidated ? Colors.green : Colors.orange),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'Por segurança, mantenha a conversa e o combinado dentro do chat do PegaeFazFree.',
                    style: TextStyle(color: Colors.black54, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_outline),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Avaliações recebidas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '${publicReviews.length}',
                        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (publicReviews.isEmpty)
                    const Text(
                      'Este usuário ainda não recebeu avaliações.',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    ...publicReviews.take(5).map(
                      (review) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F6F1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${review.rating.toStringAsFixed(1)} ⭐',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const Spacer(),
                                Text(
                                  formatDate(review.createdAt),
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                            if (review.comment.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(review.comment, style: const TextStyle(height: 1.35)),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!isOwnProfile && !isOfficial) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: reportProfile,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Denunciar usuário'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileMetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class LegalTextPage extends StatelessWidget {
  final String title;
  final String body;

  const LegalTextPage({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: const TextStyle(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String category;
  final bool selected;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              width: 92,
              height: 74,
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFFF3C62F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? Colors.black : Colors.white70,
                  width: selected ? 2 : 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                categoryIcon(category),
                size: 34,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              category,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: selected ? Colors.black : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PopularServiceCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback? onTap;

  const PopularServiceCard({
    super.key,
    required this.job,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 188,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE27A), Color(0xFFF4C61D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: job.photoUrl != null && job.photoUrl!.trim().isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(job.photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: job.photoUrl != null && job.photoUrl!.trim().isNotEmpty
                  ? Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0x66000000), Color(0x11000000)],
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        categoryIcon(job.category),
                        size: 62,
                        color: Colors.black87,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.subservice.isNotEmpty ? job.subservice : job.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            money(job.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  final JobModel job;
  final Future Function()? onChanged;
  final bool forceOwnerMode;
  final VoidCallback? onTap;
  final bool adminMode;

  const RequestCard({
    super.key,
    required this.job,
    this.onChanged,
    this.forceOwnerMode = false,
    this.onTap,
    this.adminMode = false,
  });

  bool get isOwner {
    if (adminMode) return true;
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    return user.id == job.clientId;
  }

  bool get canConcludeByClient {
    if (adminMode) {
      return job.status == 'in_progress' || job.status == 'proposal_sent';
    }
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    return user.id == job.clientId &&
        (job.status == 'in_progress' || job.status == 'proposal_sent') &&
        job.paymentStatus == 'paid';
  }

  bool get canReview {
    final user = supabase.auth.currentUser;
    if (user == null || job.status != 'done') return false;
    if (adminMode) return true;
    if (user.id == job.clientId) return job.workerId != null && job.workerId!.isNotEmpty;
    return user.id == job.workerId;
  }

  bool get canOpenChat {
    if (adminMode) return true;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    if (user.id == job.clientId) {
      return job.workerId != null && job.workerId!.isNotEmpty;
    }

    return job.workerId == null || job.workerId == user.id;
  }

  bool get canStartRoute {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    return job.workerId == user.id &&
        (job.status == 'proposal_sent' || job.status == 'in_progress');
  }

  bool get canWorkerSubmitCompletionEvidence {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    return job.workerId == user.id &&
        job.status != 'done' &&
        job.status != 'cancelled' &&
        (job.status == 'proposal_sent' || job.status == 'in_progress');
  }

  Future<void> deleteJob(BuildContext context) async {
    try {
      await supabase.from('jobs').delete().eq('id', job.id);
      if (onChanged != null) await onChanged!();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço excluído com sucesso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  Future<void> updateStatus(BuildContext context, String newStatus) async {
    try {
      await supabase.from('jobs').update({'status': newStatus}).eq('id', job.id);

      if (onChanged != null) await onChanged!();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status alterado para ${statusLabel(newStatus)}.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao alterar status: $e')),
        );
      }
    }
  }

  Future<void> acceptSpecificProposal(BuildContext context, ProposalModel proposal, {bool closeDialog = true}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (!adminMode && user.id != job.clientId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Somente o cliente pode aceitar uma proposta.')),
      );
      return;
    }

    try {
      await supabase.from('proposals').update({'status': 'accepted'}).eq('id', proposal.id);
      await supabase
          .from('proposals')
          .update({'status': 'rejected'})
          .eq('job_id', job.id)
          .neq('id', proposal.id);

      await supabase.from('jobs').update({
        'worker_id': proposal.workerId,
        'price': proposal.amount,
        'status': 'proposal_sent',
      }).eq('id', job.id);

      await createNotificationForUser(
        userId: proposal.workerId,
        title: 'Proposta aceita',
        body: 'Sua proposta para ${job.title} foi aceita. Valor: ${money(proposal.amount)}',
        referenceType: 'proposal',
        referenceId: job.id,
      );

      if (onChanged != null) await onChanged!();

      if (context.mounted) {
        if (closeDialog) Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposta aceita. Prestador vinculado ao serviço.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aceitar proposta: $e')),
        );
      }
    }
  }

  Future<void> rejectSpecificProposal(BuildContext context, ProposalModel proposal) async {
    try {
      await supabase.from('proposals').update({'status': 'rejected'}).eq('id', proposal.id);
      if (onChanged != null) await onChanged!();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposta recusada.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao recusar proposta: $e')),
        );
      }
    }
  }

  Future<void> openCounterProposalForReceivedProposal(
    BuildContext context,
    ProposalModel proposal,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (!adminMode && user.id != job.clientId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Somente o cliente pode enviar contra-proposta para este serviço.')),
      );
      return;
    }

    await _openProposalDialog(
      context,
      isCounter: true,
      targetWorkerId: proposal.workerId,
    );
  }

  Widget buildClientProposalsPreview(BuildContext context, bool ownerMode) {
    if (!ownerMode || (job.status != 'open' && job.status != 'proposal_sent')) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<ProposalModel>>(
      future: loadJobProposals(job.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8DE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5C14A)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Expanded(child: Text('Carregando propostas recebidas...')),
              ],
            ),
          );
        }

        final proposals = snapshot.data ?? const <ProposalModel>[];
        if (proposals.isEmpty) {
          return const SizedBox.shrink();
        }

        final pendingCount = proposals.where((p) => p.status == 'pending').length;
        final acceptedCount = proposals.where((p) => p.status == 'accepted').length;
        final visibleProposals = proposals.take(2).toList();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8DE),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5C14A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.list_alt_outlined, color: Colors.black87),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pendingCount > 0
                          ? '$pendingCount proposta(s) aguardando resposta'
                          : acceptedCount > 0
                              ? 'Proposta aceita neste serviço'
                              : '${proposals.length} proposta(s) recebida(s)',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...visibleProposals.map((proposal) {
                final accepted = proposal.status == 'accepted';
                final rejected = proposal.status == 'rejected';
                final color = proposalStatusColor(proposal.status);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              proposal.isCounter ? 'Contra-proposta' : 'Proposta',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            proposalStatusLabel(proposal.status),
                            style: TextStyle(color: color, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Valor: ${money(proposal.amount)}'),
                      if (proposal.message.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          proposal.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87, height: 1.3),
                        ),
                      ],
                      if (!accepted && !rejected) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => openUserPublicProfile(context, proposal.workerId),
                              icon: const Icon(Icons.person_outline),
                              label: const Text('Ver perfil'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => acceptSpecificProposal(context, proposal, closeDialog: false),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Aceitar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4C61D),
                                foregroundColor: Colors.black,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => rejectSpecificProposal(context, proposal),
                              icon: const Icon(Icons.close),
                              label: const Text('Recusar'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => openCounterProposalForReceivedProposal(context, proposal),
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Contra-proposta'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (proposals.length > visibleProposals.length)
                Text(
                  '+${proposals.length - visibleProposals.length} proposta(s) em “Ver propostas”.',
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openProposalsDialog(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ver e gerenciar todas as propostas'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> openProposalsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Propostas recebidas'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<ProposalModel>>(
              future: loadJobProposals(job.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final proposals = snapshot.data ?? const <ProposalModel>[];
                if (proposals.isEmpty) {
                  return const Text(
                    'Nenhuma proposta recebida ainda. Quando um prestador enviar uma proposta, ela aparecerá aqui.',
                    style: TextStyle(height: 1.35),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: proposals.map((proposal) {
                      final accepted = proposal.status == 'accepted';
                      final rejected = proposal.status == 'rejected';
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5F1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accepted
                                ? Colors.green
                                : rejected
                                    ? Colors.redAccent
                                    : Colors.black12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              proposal.isCounter ? 'Contra-proposta' : 'Proposta',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text('Valor: ${money(proposal.amount)}'),
                            Text('Status: ${proposalStatusLabel(proposal.status)}'),
                            if (proposal.message.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(proposal.message),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => openUserPublicProfile(dialogContext, proposal.workerId),
                                  icon: const Icon(Icons.person_outline),
                                  label: const Text('Ver perfil'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: accepted || rejected
                                      ? null
                                      : () => acceptSpecificProposal(dialogContext, proposal),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text(accepted ? 'Aceita' : 'Aceitar proposta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF4C61D),
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: accepted || rejected
                                      ? null
                                      : () => rejectSpecificProposal(dialogContext, proposal),
                                  icon: const Icon(Icons.close),
                                  label: Text(rejected ? 'Recusada' : 'Recusar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: accepted || rejected
                                      ? null
                                      : () => openCounterProposalForReceivedProposal(dialogContext, proposal),
                                  icon: const Icon(Icons.swap_horiz),
                                  label: const Text('Contra-proposta'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> openCompletionEvidenceOptions(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comprovar conclusão do trabalho',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tire uma foto agora mostrando o serviço concluído. A galeria não é aceita nessa etapa. A foto fica como comprovação para cliente e ADM e não libera dinheiro automaticamente.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF4C61D),
                    child: Icon(Icons.photo_camera_outlined, color: Colors.black),
                  ),
                  title: const Text('Tirar foto pela câmera'),
                  onTap: () {
                    Navigator.pop(context);
                    submitCompletionEvidence(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> submitCompletionEvidence(BuildContext context) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (job.workerId != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Somente o prestador vinculado pode enviar a comprovação.')),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 72,
        requestFullMetadata: false,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('A imagem selecionada está vazia. Escolha outra foto.');
      }

      final fileName =
          'completion-evidence/${job.id}/${DateTime.now().millisecondsSinceEpoch}_${user.id}.jpg';

      await supabase.storage.from('job-photos').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = supabase.storage.from('job-photos').getPublicUrl(fileName);
      final completedAt = DateTime.now().toIso8601String();

      final savedJob = await supabase
          .from('jobs')
          .update({
            'completion_photo_url': publicUrl,
            'worker_completed_at': completedAt,
            'completion_status': 'submitted',
          })
          .eq('id', job.id)
          .eq('worker_id', user.id)
          .select(
            'id, completion_photo_url, worker_completed_at, completion_status',
          )
          .maybeSingle();

      final savedUrl = savedJob?['completion_photo_url']?.toString().trim() ?? '';
      final savedStatus = savedJob?['completion_status']?.toString().trim() ?? '';

      if (savedJob == null ||
          savedUrl.isEmpty ||
          savedUrl != publicUrl ||
          savedStatus != 'submitted') {
        try {
          await supabase.storage.from('job-photos').remove([fileName]);
        } catch (_) {
          // Se a limpeza falhar, o erro principal continua sendo o salvamento no banco.
        }

        throw Exception(
          'A foto foi capturada, mas o banco não confirmou o registro da comprovação. '
          'Verifique a permissão de atualização do prestador na tabela jobs.',
        );
      }

      await createNotificationForUser(
        userId: job.clientId,
        title: 'Trabalho concluído pelo prestador',
        body: 'O prestador enviou uma foto de comprovação do serviço: ${job.title}',
        referenceType: 'job',
        referenceId: job.id,
      );

      if (onChanged != null) await onChanged!();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto do trabalho concluído salva e registrada com sucesso.')),
        );
      }
    } on StorageException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar foto: ${e.message}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar comprovação: $e')),
        );
      }
    }
  }

  Future<void> openReviewDialog(BuildContext context) async {
    final result = await showDialog<_ReviewResult>(
      context: context,
      builder: (_) => const ReviewDialog(),
    );

    if (result == null) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final reviewedId =
          user.id == job.clientId ? (job.workerId ?? job.clientId) : job.clientId;

      if (reviewedId == user.id) {
        throw Exception('Não é possível avaliar o próprio perfil.');
      }

      await supabase.from('reviews').upsert({
        'job_id': job.id,
        'reviewer_id': user.id,
        'reviewed_id': reviewedId,
        'rating': result.rating,
        'comment': result.comment,
      }, onConflict: 'job_id,reviewer_id,reviewed_id');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avaliação enviada com sucesso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao avaliar: $e')),
        );
      }
    }
  }

  Future<void> openChat(BuildContext context) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (!adminMode && user.id != job.clientId) {
        if (job.workerId == null || job.workerId!.isEmpty) {
          await supabase.from('jobs').update({
            'worker_id': user.id,
            if (job.status == 'open') 'status': 'proposal_sent',
          }).eq('id', job.id);

          if (onChanged != null) await onChanged!();
        } else if (job.workerId != user.id) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Este serviço já está vinculado a outro prestador.'),
              ),
            );
          }
          return;
        }
      }

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            jobId: job.id,
            jobTitle: job.title,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir chat: $e')),
        );
      }
    }
  }

  Future<void> acceptJob(BuildContext context) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (user.id == job.clientId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não pode aceitar o próprio serviço.')),
      );
      return;
    }

    if (job.workerId != null && job.workerId!.isNotEmpty && job.workerId != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este serviço já está vinculado a outro prestador.')),
      );
      return;
    }

    try {
      await supabase.from('jobs').update({
        'worker_id': user.id,
        if (job.status == 'open') 'status': 'proposal_sent',
      }).eq('id', job.id);

      await createNotificationForUser(
        userId: job.clientId,
        title: 'Trabalho aceito',
        body: 'Um prestador aceitou o serviço: ${job.title}',
        referenceType: 'job',
        referenceId: job.id,
      );

      if (onChanged != null) await onChanged!();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trabalho aceito com sucesso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aceitar trabalho: $e')),
        );
      }
    }
  }

  Future<void> _openProposalDialog(BuildContext context, {required bool isCounter, String? targetWorkerId}) async {
    final result = await showDialog<_ProposalDialogResult>(
      context: context,
      builder: (_) => ProposalDialog(
        basePrice: job.price,
        isCounter: isCounter,
      ),
    );

    if (result == null) return;

    try {
      await createOrUpdateProposal(
        job: job,
        amount: result.amount,
        message: result.message,
        isCounter: isCounter,
        targetWorkerId: targetWorkerId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCounter
                ? 'Contra-proposta enviada com sucesso.'
                : 'Proposta enviada com sucesso.'),
          ),
        );
      }
      if (onChanged != null) await onChanged!();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na proposta: $e')),
        );
      }
    }
  }

  void openUserPublicProfile(BuildContext context, String userId) {
    final targetId = userId.trim();
    if (targetId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(profileId: targetId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerMode = adminMode || forceOwnerMode || isOwner;
    final currentUserId = supabase.auth.currentUser?.id;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFF0E7D8)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE27A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    categoryIcon(job.category),
                    color: Colors.black,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        job.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (job.subservice.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          job.subservice,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.publicLocationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5CC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        money(job.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor(job.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        statusLabel(job.status),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: statusColor(job.status),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (job.photoUrl != null && job.photoUrl!.trim().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  job.photoUrl!,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (job.photoUrl != null && job.photoUrl!.trim().isNotEmpty) const SizedBox(height: 12),
            if (job.completionPhotoUrl != null && job.completionPhotoUrl!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8ED),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.green.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_outlined, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Comprovação de conclusão enviada pelo prestador',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    if (job.workerCompletedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Enviada em ${formatDate(job.workerCompletedAt)}',
                        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        job.completionPhotoUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Text('Não foi possível carregar a foto de comprovação.'),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                job.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ),
            buildClientProposalsPreview(context, ownerMode),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  'Criado em ${formatDate(job.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoTag(
                  icon: Icons.account_balance_wallet_outlined,
                  text: paymentStatusLabel(job.paymentStatus),
                ),
                _InfoTag(
                  icon: Icons.lock_clock_outlined,
                  text: escrowStatusLabel(job.escrowStatus),
                ),
                if (!ownerMode &&
                    currentUserId != null &&
                    currentUserId != job.clientId &&
                    job.clientId.trim().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => openUserPublicProfile(context, job.clientId),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Perfil do cliente'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (ownerMode &&
                    job.workerId != null &&
                    job.workerId!.trim().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => openUserPublicProfile(context, job.workerId!),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Perfil do prestador'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (canOpenChat)
                  OutlinedButton.icon(
                    onPressed: () => openChat(context),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(adminMode ? 'Abrir chat' : 'Conversar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (!ownerMode && job.status == 'open' && (job.workerId == null || job.workerId!.isEmpty))
                  ElevatedButton.icon(
                    onPressed: () => acceptJob(context),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aceitar trabalho'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4C61D),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (!ownerMode && job.status == 'open')
                  OutlinedButton.icon(
                    onPressed: () => _openProposalDialog(context, isCounter: false),
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Enviar proposta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (canStartRoute)
                  ElevatedButton.icon(
                    onPressed: () => openJobRouteInMaps(context, job),
                    icon: const Icon(Icons.route),
                    label: const Text('Iniciar rota'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4C61D),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (!ownerMode && job.workerId == supabase.auth.currentUser?.id && job.status != 'done' && job.status != 'cancelled')
                  OutlinedButton.icon(
                    onPressed: () => _openProposalDialog(context, isCounter: true),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Contra-proposta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (ownerMode && (job.status == 'open' || job.status == 'proposal_sent'))
                  OutlinedButton.icon(
                    onPressed: () => openProposalsDialog(context),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Ver propostas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (ownerMode && (job.status == 'open' || job.status == 'proposal_sent') && job.workerId != null && job.workerId!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _openProposalDialog(context, isCounter: true, targetWorkerId: job.workerId),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Contra-proposta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (ownerMode && job.status == 'open')
                  ElevatedButton.icon(
                    onPressed: () => openProposalsDialog(context),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aceitar proposta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4C61D),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (ownerMode && job.status == 'proposal_sent')
                  ElevatedButton.icon(
                    onPressed: () => updateStatus(context, 'in_progress'),
                    icon: const Icon(Icons.handyman),
                    label: const Text('Iniciar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (ownerMode && job.paymentStatus != 'paid' && job.status != 'done' && job.status != 'cancelled')
                  ElevatedButton.icon(
                    onPressed: () => createMarketplacePayment(context, job),
                    icon: const Icon(Icons.payment),
                    label: const Text('Pagar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await syncJobPaymentStatus(job.id);
                    if (onChanged != null) await onChanged!();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pagamento atualizado.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Atualizar pagamento'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFE5D7B8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (ownerMode && job.paymentStatus == 'paid' && job.status != 'done' && job.status != 'cancelled' && job.completionStatus != 'submitted')
                  OutlinedButton.icon(
                    onPressed: () async {
                      await requestPaymentRefund(context, job);
                      if (onChanged != null) await onChanged!();
                    },
                    icon: const Icon(Icons.undo),
                    label: const Text('Solicitar reembolso'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (canWorkerSubmitCompletionEvidence)
                  ElevatedButton.icon(
                    onPressed: () => openCompletionEvidenceOptions(context),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Trabalho concluído'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (canConcludeByClient)
                  ElevatedButton.icon(
                    onPressed: () => confirmConclusionAndRelease(context, job),
                    icon: const Icon(Icons.verified),
                    label: const Text('Trabalho concluído'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (ownerMode && job.status != 'cancelled' && job.status != 'done')
                  OutlinedButton.icon(
                    onPressed: () => updateStatus(context, 'cancelled'),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (canReview)
                  OutlinedButton.icon(
                    onPressed: () => openReviewDialog(context),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Avaliar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                if (ownerMode)
                  IconButton(
                    onPressed: () => deleteJob(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Excluir',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProposalDialog extends StatefulWidget {
  final double basePrice;
  final bool isCounter;

  const ProposalDialog({
    super.key,
    required this.basePrice,
    required this.isCounter,
  });

  @override
  State<ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<ProposalDialog> {
  late final TextEditingController amountController;
  final TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(text: widget.basePrice.toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  void dispose() {
    amountController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCounter ? 'Enviar contra-proposta' : 'Enviar proposta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InputField(
            controller: amountController,
            hint: 'Valor da proposta',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          InputField(
            controller: messageController,
            hint: 'Mensagem da proposta',
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
            if (amount == null) return;
            Navigator.pop(
              context,
              _ProposalDialogResult(
                amount: amount,
                message: messageController.text.trim(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF4C61D),
            foregroundColor: Colors.black,
          ),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

class _ProposalDialogResult {
  final double amount;
  final String message;

  const _ProposalDialogResult({
    required this.amount,
    required this.message,
  });
}

class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double rating = 5;
  final commentController = TextEditingController();

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Avaliar serviço'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: () {
                  setState(() {
                    rating = (index + 1).toDouble();
                  });
                },
                icon: Icon(
                  rating >= index + 1 ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              ),
            ),
          ),
          TextField(
            controller: commentController,
            maxLines: 3,
            decoration: fieldDecoration('Comentário'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _ReviewResult(
                rating: rating,
                comment: commentController.text.trim(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF4C61D),
            foregroundColor: Colors.black,
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ReviewResult {
  final double rating;
  final String comment;

  const _ReviewResult({
    required this.rating,
    required this.comment,
  });
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoTag({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}


class WorkerResumePage extends StatefulWidget {
  const WorkerResumePage({super.key});

  @override
  State<WorkerResumePage> createState() => _WorkerResumePageState();
}

class _WorkerResumePageState extends State<WorkerResumePage> {
  bool loading = true;
  bool saving = false;
  final fullNameController = TextEditingController();
  final headlineController = TextEditingController();
  final summaryController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final phoneController = TextEditingController();
  final desiredCategoriesController = TextEditingController();
  final experienceController = TextEditingController();
  final educationController = TextEditingController();
  final availabilityController = TextEditingController();
  final councilNumberController = TextEditingController();
  final councilUfController = TextEditingController();
  final rqeController = TextEditingController();
  WorkerResumeModel? loadedResume;

  bool get requiresCouncil => specialtyNeedsProfessionalCouncil('${headlineController.text} ${desiredCategoriesController.text}');
  String get councilType => requiredCouncilForText('${headlineController.text} ${desiredCategoriesController.text}');
  bool get requiresRqe => needsRqeForText('${headlineController.text} ${desiredCategoriesController.text}');

  @override
  void initState() {
    super.initState();
    loadResume();
    headlineController.addListener(() => mounted ? setState(() {}) : null);
    desiredCategoriesController.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    fullNameController.dispose();
    headlineController.dispose();
    summaryController.dispose();
    cityController.dispose();
    stateController.dispose();
    phoneController.dispose();
    desiredCategoriesController.dispose();
    experienceController.dispose();
    educationController.dispose();
    availabilityController.dispose();
    councilNumberController.dispose();
    councilUfController.dispose();
    rqeController.dispose();
    super.dispose();
  }

  Future<void> loadResume() async {
    loading = true;
    if (mounted) setState(() {});
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await getCurrentProfile();
      if (profile != null) {
        fullNameController.text = profile.name;
        phoneController.text = profile.phone ?? '';
        if ((profile.specialty ?? '').isNotEmpty) {
          headlineController.text = profile.specialty!;
        }
      }
      final response = await supabase.from('worker_resumes').select().eq('worker_id', user.id).maybeSingle();
      if (response != null) {
        final resume = WorkerResumeModel.fromMap(Map<String, dynamic>.from(response));
        loadedResume = resume;
        fullNameController.text = resume.fullName;
        headlineController.text = resume.headline;
        summaryController.text = resume.summary;
        cityController.text = resume.city;
        stateController.text = resume.state;
        phoneController.text = resume.phone;
        desiredCategoriesController.text = resume.desiredCategories;
        experienceController.text = resume.experience;
        educationController.text = resume.education;
        availabilityController.text = resume.availability;
        councilNumberController.text = resume.professionalCouncilNumber;
        councilUfController.text = resume.professionalCouncilUf;
        rqeController.text = resume.professionalRqe;
      }
    } catch (_) {}
    loading = false;
    if (mounted) setState(() {});
  }

  Future<void> saveResume() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final headline = headlineController.text.trim();
    final desired = desiredCategoriesController.text.trim();
    final requires = specialtyNeedsProfessionalCouncil('$headline $desired');
    final type = requiredCouncilForText('$headline $desired');
    final number = councilNumberController.text.trim();
    final uf = councilUfController.text.trim().toUpperCase();
    final rqe = rqeController.text.trim();

    if (requires && (number.isEmpty || uf.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Para esta profissão, informe $type e UF.')),
      );
      return;
    }
    if (needsRqeForText('$headline $desired') && rqe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Para especialidades médicas, informe também o RQE.')),
      );
      return;
    }

    saving = true;
    if (mounted) setState(() {});
    try {
      await supabase.from('worker_resumes').upsert({
        'worker_id': user.id,
        'full_name': fullNameController.text.trim(),
        'headline': headline,
        'summary': summaryController.text.trim(),
        'city': cityController.text.trim(),
        'state': stateController.text.trim(),
        'phone': phoneController.text.trim(),
        'desired_categories': desired,
        'experience': experienceController.text.trim(),
        'education': educationController.text.trim(),
        'availability': availabilityController.text.trim(),
        'professional_council_type': requires ? type : '',
        'professional_council_number': requires ? number : '',
        'professional_council_uf': requires ? uf : '',
        'professional_rqe': requiresRqe ? rqe : '',
        'professional_validated': loadedResume?.professionalValidated == true && requires,
        'professional_validated_at': loadedResume?.professionalValidated == true && requires ? (loadedResume?.professionalValidatedAt ?? DateTime.now().toIso8601String()) : null,
        'validated_seal': loadedResume?.professionalValidated == true && requires ? 'Profissional validado' : '',
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'worker_id');

      await supabase.from('profiles').update({
        'specialty': headline,
      }).eq('id', user.id);

      if (requires) {
        final admins = await supabase.from('profiles').select('id').eq('role', roleAdmin);
        for (final item in (admins as List)) {
          final adminId = (item['id'] ?? '').toString();
          if (adminId.isNotEmpty) {
            await createNotificationForUser(
              userId: adminId,
              title: 'Verificação profissional pendente',
              body: '${fullNameController.text.trim()} enviou $type para validação.',
              referenceType: 'professional_validation',
              referenceId: user.id,
            );
          }
        }
      }

      await notifyCompaniesAboutResume(
        workerId: user.id,
        headline: headline.isEmpty ? fullNameController.text.trim() : headline,
        categories: desired,
      );
      await loadResume();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Currículo salvo com sucesso.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar currículo: $e')));
    } finally {
      saving = false;
      if (mounted) setState(() {});
    }
  }

  Future<List<JobModel>> loadMatchingJobs() async {
    final desired = desiredCategoriesController.text.trim();
    if (desired.isEmpty) return [];
    final categories = desired.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final response = await supabase.from('jobs').select().order('created_at', ascending: false);
    final all = (response as List).map((e) => JobModel.fromMap(Map<String, dynamic>.from(e))).toList();
    return all.where((job) => categories.any((cat) => job.category.toLowerCase().contains(cat.toLowerCase()) || job.subservice.toLowerCase().contains(cat.toLowerCase()))).take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu currículo profissional')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monte seu currículo profissional para ser encontrado por empresas, clientes e contratantes no PegaeFazFree.', style: TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                      const SizedBox(height: 10),
                      if (requiresCouncil)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: loadedResume?.professionalValidated == true ? const Color(0xFFE8F8EA) : const Color(0xFFFFF4D6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(loadedResume?.professionalValidated == true ? Icons.verified : Icons.pending_actions, color: loadedResume?.professionalValidated == true ? Colors.green : Colors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  loadedResume?.professionalValidated == true
                                      ? '$councilType verificado pelo ADM • registro profissional confirmado'
                                      : '$councilType pendente de verificação pelo ADM',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InputField(controller: fullNameController, hint: 'Nome completo'),
                const SizedBox(height: 12),
                InputField(controller: headlineController, hint: 'Título profissional / cargo desejado'),
                const SizedBox(height: 12),
                InputField(controller: summaryController, hint: 'Resumo profissional', maxLines: 4),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: InputField(controller: cityController, hint: 'Cidade')), const SizedBox(width: 12), Expanded(child: InputField(controller: stateController, hint: 'UF'))]),
                const SizedBox(height: 12),
                InputField(controller: phoneController, hint: 'Telefone'),
                const SizedBox(height: 12),
                InputField(controller: desiredCategoriesController, hint: 'Áreas de interesse (separe por vírgula)'),
                const SizedBox(height: 12),
                InputField(controller: experienceController, hint: 'Experiência', maxLines: 4),
                const SizedBox(height: 12),
                InputField(controller: educationController, hint: 'Cursos / formação', maxLines: 3),
                const SizedBox(height: 12),
                InputField(controller: availabilityController, hint: 'Disponibilidade'),
                if (requiresCouncil) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Validação profissional obrigatória • $councilType', style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text('Para esta profissão regulamentada, informe $councilType e UF. A confirmação do registro profissional aparece depois da aprovação do ADM.', style: const TextStyle(height: 1.35, color: Colors.black87)),
                        const SizedBox(height: 12),
                        InputField(controller: councilNumberController, hint: 'Número do $councilType'),
                        const SizedBox(height: 12),
                        InputField(controller: councilUfController, hint: 'UF do $councilType'),
                        if (requiresRqe) ...[
                          const SizedBox(height: 12),
                          InputField(controller: rqeController, hint: 'RQE (obrigatório para especialidade médica)'),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: saving ? null : saveResume,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Salvando...' : 'Salvar currículo'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF4C61D), foregroundColor: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Vagas do seu interesse', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 10),
                FutureBuilder<List<JobModel>>(
                  future: loadMatchingJobs(),
                  builder: (context, snapshot) {
                    final jobs = snapshot.data ?? [];
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (jobs.isEmpty) return const Text('Ainda não encontrei vagas compatíveis com as áreas informadas.');
                    return Column(
                      children: jobs.map((job) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(job.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('${job.category} • ${job.publicLocationLabel}'),
                          const SizedBox(height: 4),
                          Text(money(job.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class CompanyResumeAccessPage extends StatefulWidget {
  const CompanyResumeAccessPage({super.key});

  @override
  State<CompanyResumeAccessPage> createState() => _CompanyResumeAccessPageState();
}

class _CompanyResumeAccessPageState extends State<CompanyResumeAccessPage> {
  bool loading = true;
  bool hasAccess = false;
  bool resumeAccessPaymentLoading = false;
  List<WorkerResumeModel> resumes = [];
  List<Map<String, dynamic>> notifications = [];
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
    searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    loading = true;
    if (mounted) setState(() {});
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final access = await supabase.from('company_resume_access').select().eq('company_id', user.id).maybeSingle();
      hasAccess = access != null && access['is_active'] == true;
      final notif = await supabase.from('app_notifications').select().eq('user_id', user.id).order('created_at', ascending: false).limit(8);
      notifications = (notif as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (hasAccess) {
        final response = await supabase.from('worker_resumes').select().eq('is_active', true).order('updated_at', ascending: false);
        resumes = (response as List).map((e) => WorkerResumeModel.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}
    loading = false;
    if (mounted) setState(() {});
  }

  Future<void> requestAccess() async {
    final user = supabase.auth.currentUser;
    if (user == null || resumeAccessPaymentLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Comprar acesso'),
        content: const Text(
          'Acesso ao banco de currículos\n\nPeríodo: 30 dias\nValor: R\$ 29,90\n\nO acesso não é renovado automaticamente. Ao confirmar, você será direcionado ao ambiente seguro de pagamento.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4C61D),
              foregroundColor: Colors.black,
            ),
            child: const Text('Continuar para pagamento'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => resumeAccessPaymentLoading = true);

    try {
      final data = await _invokeAuthenticatedFunction(
        'stripe-create-resume-access-payment',
        body: {'company_id': user.id},
      );

      final rawUrl = data['checkout_url'] ?? data['url'] ?? data['session_url'];
      final checkoutUrl = rawUrl?.toString();

      if (checkoutUrl == null || checkoutUrl.trim().isEmpty) {
        throw Exception(
          data['message']?.toString() ??
              'Não foi possível gerar o pagamento do acesso aos currículos.',
        );
      }

      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null) throw Exception('Link de pagamento inválido.');

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Pagamento do acesso'),
            content: const Text(
              'Não consegui abrir o pagamento automaticamente. Toque em “Abrir pagamento” ou copie o link.',
              style: TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: checkoutUrl));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link de pagamento copiado.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar link'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir pagamento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4C61D),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pagamento iniciado. Após a confirmação, o acesso será liberado.'),
        ),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar pagamento: $e')),
      );
    } finally {
      if (mounted) setState(() => resumeAccessPaymentLoading = false);
    }
  }

  Future<void> syncResumeAccessPayment() async {
    final user = supabase.auth.currentUser;
    if (user == null || resumeAccessPaymentLoading) return;

    setState(() => resumeAccessPaymentLoading = true);

    try {
      final session = supabase.auth.currentSession;
      await supabase.functions.invoke(
        'stripe-sync-resume-access-payment',
        headers: session == null
            ? {'apikey': supabaseAnonKey}
            : {
                'Authorization': 'Bearer ${session.accessToken}',
                'apikey': supabaseAnonKey,
              },
        body: {
          'company_id': user.id,
        },
      );

      await load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasAccess
              ? 'Pagamento confirmado. Acesso aos currículos liberado.'
              : 'Pagamento atualizado. Se já pagou, aguarde alguns instantes e tente novamente.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar pagamento: $e')));
    } finally {
      if (mounted) setState(() => resumeAccessPaymentLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = searchController.text.trim().toLowerCase();
    final filtered = resumes.where((r) => q.isEmpty || r.fullName.toLowerCase().contains(q) || r.headline.toLowerCase().contains(q) || r.desiredCategories.toLowerCase().contains(q) || r.professionalCouncilType.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Banco de currículos')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Talentos da plataforma', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              Text(hasAccess ? 'Seu acesso ao banco de currículos está liberado.' : 'Para visualizar todos os currículos criados na plataforma, libere o acesso empresarial.', style: const TextStyle(height: 1.4)),
              const SizedBox(height: 12),
              if (!hasAccess) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: resumeAccessPaymentLoading ? null : requestAccess,
                    icon: resumeAccessPaymentLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.payment),
                    label: Text(resumeAccessPaymentLoading ? 'Preparando acesso...' : 'Comprar acesso'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF4C61D), foregroundColor: Colors.black),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: resumeAccessPaymentLoading ? null : syncResumeAccessPayment,
                    icon: const Icon(Icons.sync),
                    label: const Text('Atualizar pagamento do acesso'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFE5D7B8)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          if (hasAccess)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                PffMetricCard(title: 'Currículos disponíveis', value: '${resumes.length}', icon: Icons.badge_outlined),
                PffMetricCard(title: 'Acesso privado', value: 'Liberado', icon: Icons.lock_open_outlined),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                PffMetricCard(title: 'Currículos disponíveis', value: 'Bloqueado', icon: Icons.lock_outline),
                PffMetricCard(title: 'Acesso privado', value: 'Pendente', icon: Icons.hourglass_empty),
              ],
            ),
          const SizedBox(height: 16),
          if (notifications.isNotEmpty) ...[
            const Text('Notificações', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 10),
            ...notifications.map((n) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((n['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text((n['body'] ?? '').toString()),
              ]),
            )),
            const SizedBox(height: 16),
          ],
          if (hasAccess) ...[
            InputField(controller: searchController, hint: 'Buscar currículo por nome, cargo, área ou conselho'),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Text('Nenhum currículo encontrado.')
            else
              ...filtered.map((resume) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Expanded(child: Text(resume.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                      if (resume.professionalValidated)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFE8F8EA), borderRadius: BorderRadius.circular(14)),
                          child: const Text('Registro profissional verificado', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(resume.headline),
                  const SizedBox(height: 6),
                  Text(resume.desiredCategories),
                  if (resume.professionalCouncilType.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${resume.professionalCouncilType}: ${resume.professionalCouncilNumber}/${resume.professionalCouncilUf}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (resume.professionalRqe.isNotEmpty)
                      Text('RQE: ${resume.professionalRqe}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 8),
                  Text('Cidade: ${resume.city} - ${resume.state}'),
                  Text('Disponibilidade: ${resume.availability}'),
                  const SizedBox(height: 8),
                  Text(resume.summary, maxLines: 4, overflow: TextOverflow.ellipsis),
                ]),
              )),
          ],
        ],
      ),
    );
  }
}

class AdminResumesPage extends StatefulWidget {
  const AdminResumesPage({super.key});

  @override
  State<AdminResumesPage> createState() => _AdminResumesPageState();
}

class _AdminResumesPageState extends State<AdminResumesPage> {
  bool loading = true;
  List<WorkerResumeModel> resumes = [];
  List<Map<String, dynamic>> accessOrders = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    loading = true;
    if (mounted) setState(() {});
    try {
      final resumeResp = await supabase.from('worker_resumes').select().order('updated_at', ascending: false);
      resumes = (resumeResp as List).map((e) => WorkerResumeModel.fromMap(Map<String, dynamic>.from(e))).toList();
      final accessResp = await supabase.from('company_resume_access').select().order('updated_at', ascending: false);
      accessOrders = (accessResp as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    loading = false;
    if (mounted) setState(() {});
  }

  Future<void> toggleResume(WorkerResumeModel resume, bool value) async {
    await supabase.from('worker_resumes').update({'is_active': value}).eq('id', resume.id);
    await load();
  }

  Future<void> approveAccess(String companyId, bool value) async {
    await supabase.from('company_resume_access').update({'is_active': value, 'status': value ? 'approved' : 'pending', 'updated_at': DateTime.now().toIso8601String()}).eq('company_id', companyId);
    await createNotificationForUser(userId: companyId, title: value ? 'Acesso liberado' : 'Acesso desativado', body: value ? 'Seu acesso ao banco de currículos foi liberado.' : 'Seu acesso ao banco de currículos foi desativado.', referenceType: 'resume_access', referenceId: companyId);
    await load();
  }

  Future<void> validateProfessional(WorkerResumeModel resume, bool value) async {
    final seal = value ? 'Profissional validado' : '';
    await supabase.from('worker_resumes').update({
      'professional_validated': value,
      'professional_validated_at': value ? DateTime.now().toIso8601String() : null,
      'validated_seal': seal,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', resume.id);
    await createNotificationForUser(
      userId: resume.workerId,
      title: value ? 'Validação profissional aprovada' : 'Validação profissional removida',
      body: value
          ? 'Seu ${resume.professionalCouncilType} foi validado pelo ADM e o registro profissional aparece como verificado.'
          : 'A validação do registro profissional foi removida pelo ADM.',
      referenceType: 'professional_validation',
      referenceId: resume.workerId,
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Currículos e acessos empresariais')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Pedidos de acesso empresariais', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          if (accessOrders.isEmpty)
            const Text('Nenhum pedido encontrado.')
          else
            ...accessOrders.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Empresa: ${(item['company_id'] ?? '').toString()}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Status: ${(item['status'] ?? 'pending').toString()}'),
                Text('Valor: R\$ 29,90'),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  ElevatedButton(onPressed: () => approveAccess((item['company_id'] ?? '').toString(), true), child: const Text('Liberar')), 
                  OutlinedButton(onPressed: () => approveAccess((item['company_id'] ?? '').toString(), false), child: const Text('Bloquear')), 
                ]),
              ]),
            )),
          const SizedBox(height: 20),
          const Text('Currículos cadastrados', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          if (resumes.isEmpty)
            const Text('Nenhum currículo cadastrado.')
          else
            ...resumes.map((resume) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Expanded(child: Text(resume.fullName, style: const TextStyle(fontWeight: FontWeight.w900))),
                    if (resume.professionalValidated)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFE8F8EA), borderRadius: BorderRadius.circular(14)),
                        child: const Text('Registro verificado', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(resume.headline),
                const SizedBox(height: 6),
                Text(resume.desiredCategories),
                if (resume.professionalCouncilType.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${resume.professionalCouncilType}: ${resume.professionalCouncilNumber}/${resume.professionalCouncilUf}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (resume.professionalRqe.isNotEmpty)
                    Text('RQE: ${resume.professionalRqe}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => validateProfessional(resume, true),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Aprovar validação'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => validateProfessional(resume, false),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Remover selo'),
                      ),
                    ],
                  ),
                ],
                SwitchListTile(
                  value: resume.isActive,
                  onChanged: (v) => toggleResume(resume, v),
                  title: const Text('Currículo ativo para empresas'),
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
            )),
        ],
      ),
    );
  }
}

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const InputField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: fieldDecoration(hint, suffixIcon: suffixIcon),
    );
  }
}

InputDecoration fieldDecoration(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );
}


class AdminCompaniesPage extends StatefulWidget {
  const AdminCompaniesPage({super.key});

  @override
  State<AdminCompaniesPage> createState() => _AdminCompaniesPageState();
}

class _AdminCompaniesPageState extends State<AdminCompaniesPage> {
  bool loading = true;
  String search = '';
  List<Map<String, dynamic>> companies = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await supabase.from('profiles').select().eq('role', roleClientCompany).order('updated_at', ascending: false);
      companies = (response as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => !isDeletedProfileMap(e))
          .toList();
    } catch (_) {
      companies = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleBlock(Map<String, dynamic> item) async {
    await supabase.from('profiles').update({'is_blocked': item['is_blocked'] == true ? false : true}).eq('id', item['id']);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = companies.where((item) {
      final q = search.toLowerCase();
      return q.isEmpty ||
          (item['name'] ?? '').toString().toLowerCase().contains(q) ||
          (item['company_name'] ?? item['company_legal_name'] ?? '').toString().toLowerCase().contains(q) ||
          (item['cnpj'] ?? item['company_cnpj'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Empresas')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: fieldDecoration('Buscar empresa, CNPJ ou responsável'),
                  onChanged: (v) => setState(() => search = v),
                ),
                const SizedBox(height: 12),
                ...filtered.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((item['company_name'] ?? item['company_legal_name'] ?? item['name'] ?? 'Empresa').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('Responsável: ${(item['company_contact_name'] ?? item['company_responsible'] ?? item['name'] ?? '').toString()}'),
                        Text('CNPJ: ${(item['cnpj'] ?? item['company_cnpj'] ?? '').toString()}'),
                        Text('Status: ${item['company_verified'] == true ? 'Verificada' : 'Pendente'}'),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton(onPressed: () async { await supabase.from('profiles').update({'company_verified': item['company_verified'] == true ? false : true}).eq('id', item['id']); await load(); }, child: Text(item['company_verified'] == true ? 'Remover selo' : 'Verificar')),
                          OutlinedButton(onPressed: () => toggleBlock(item), child: Text(item['is_blocked'] == true ? 'Desbloquear' : 'Bloquear')),
                        ]),
                      ]),
                    )),
              ],
            ),
    );
  }
}

class AdminCmsPage extends StatefulWidget {
  const AdminCmsPage({super.key});

  @override
  State<AdminCmsPage> createState() => _AdminCmsPageState();
}

class _AdminCmsPageState extends State<AdminCmsPage> {
  bool loading = true;
  List<Map<String, dynamic>> jobs = [];
  List<Map<String, dynamic>> reviews = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      jobs = (await supabase.from('jobs').select('id,title,category,photo_url,status').order('created_at', ascending: false).limit(20) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) { jobs = []; }
    try {
      reviews = (await supabase.from('reviews').select('id,comment,rating').order('created_at', ascending: false).limit(20) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) { reviews = []; }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CMS e moderação')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _AdminSectionTitle('Banners e avisos'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Gerencie avisos globais, promoções e banners de destaque do app.', style: TextStyle(height: 1.4)),
              const SizedBox(height: 10),
              ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnnouncementsPage())), icon: const Icon(Icons.campaign_outlined), label: const Text('Abrir banners e avisos')),
            ]),
          ),
          const SizedBox(height: 16),
          const _AdminSectionTitle('Catálogo / serviços publicados'),
          ...jobs.take(8).map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((item['title'] ?? 'Serviço').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
              Text((item['category'] ?? '').toString()),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () async { await supabase.from('jobs').update({'status': 'cancelled'}).eq('id', item['id']); await load(); }, child: const Text('Ocultar')),
                OutlinedButton(onPressed: () async { await supabase.from('jobs').delete().eq('id', item['id']); await load(); }, child: const Text('Excluir')),
              ])
            ]),
          )),
          const SizedBox(height: 16),
          const _AdminSectionTitle('Moderação de avaliações'),
          ...reviews.take(8).map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nota ${(item['rating'] ?? '').toString()}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text((item['comment'] ?? 'Sem comentário').toString()),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () async { await supabase.from('reviews').delete().eq('id', item['id']); await load(); }, child: const Text('Remover avaliação')),
            ]),
          )),
        ],
      ),
    );
  }
}

class AdminProviderVerificationPage extends StatefulWidget {
  const AdminProviderVerificationPage({super.key});

  @override
  State<AdminProviderVerificationPage> createState() =>
      _AdminProviderVerificationPageState();
}

class _AdminProviderVerificationPageState
    extends State<AdminProviderVerificationPage> {
  bool loading = true;
  List<Map<String, dynamic>> workers = [];
  Map<String, Map<String, dynamic>> resumesByWorkerId = {};
  Map<String, WorkerTrustModel> trustByWorkerId = {};
  Map<String, WorkerIdentityEvidenceModel> evidenceByWorkerId = {};

  int get pioneerCount =>
      trustByWorkerId.values.where((item) => item.pioneerNumber != null).length;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);

    try {
      final profilesResponse = await supabase
          .from('profiles')
          .select()
          .eq('role', roleWorker)
          .order('name');

      workers = (profilesResponse as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      try {
        final resumeResponse = await supabase
            .from('worker_resumes')
            .select()
            .order('updated_at', ascending: false);

        resumesByWorkerId = {
          for (final item in (resumeResponse as List))
            (item['worker_id'] ?? '').toString():
                Map<String, dynamic>.from(item),
        };
      } catch (_) {
        resumesByWorkerId = {};
      }

      try {
        final verificationResponse = await supabase
            .from('worker_identity_verifications')
            .select();

        trustByWorkerId = {
          for (final item in (verificationResponse as List))
            (item['worker_id'] ?? '').toString():
                WorkerTrustModel.fromMap(Map<String, dynamic>.from(item)),
        };
      } catch (_) {
        trustByWorkerId = {};
      }

      try {
        final evidenceResponse = await supabase
            .from('worker_identity_evidence')
            .select();

        evidenceByWorkerId = {
          for (final item in (evidenceResponse as List))
            (item['worker_id'] ?? '').toString():
                WorkerIdentityEvidenceModel.fromMap(
                  Map<String, dynamic>.from(item),
                ),
        };
      } catch (_) {
        evidenceByWorkerId = {};
      }
    } catch (_) {
      workers = [];
    }

    if (mounted) setState(() => loading = false);
  }

  WorkerTrustModel trustFor(String workerId) =>
      trustByWorkerId[workerId] ?? WorkerTrustModel(workerId: workerId);

  WorkerIdentityEvidenceModel evidenceFor(String workerId) =>
      evidenceByWorkerId[workerId] ??
      WorkerIdentityEvidenceModel(workerId: workerId);

  Future<void> showIdentityEvidence(Map<String, dynamic> worker) async {
    final workerId = (worker['id'] ?? '').toString();
    final evidence = evidenceFor(workerId);
    if (!evidence.hasRequiredFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este prestador ainda não enviou documento e selfie.')),
      );
      return;
    }

    try {
      final documentUrl = await supabase.storage
          .from('identity-verification')
          .createSignedUrl(evidence.documentPath, 300);
      final selfieUrl = await supabase.storage
          .from('identity-verification')
          .createSignedUrl(evidence.selfiePath, 300);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Conferir identidade'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Documento: ${evidence.documentType.isEmpty ? 'Não informado' : evidence.documentType}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (evidence.submittedAt != null)
                    Text(
                      'Enviado em ${formatDate(evidence.submittedAt)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  const SizedBox(height: 12),
                  const Text('Documento', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      documentUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Não foi possível abrir a imagem do documento.'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Selfie', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      selfieUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Não foi possível abrir a selfie.'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir os documentos privados: $e')),
      );
    }
  }

  Future<void> setIdentityStatus(
    Map<String, dynamic> worker,
    String status,
  ) async {
    final workerId = (worker['id'] ?? '').toString();
    if (workerId.isEmpty) return;

    final evidence = evidenceFor(workerId);
    if (status == 'verified' && !evidence.hasRequiredFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível aprovar sem documento e selfie enviados pelo prestador.'),
        ),
      );
      return;
    }

    String reviewNote = '';
    if (status == 'rejected') {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pedir revisão'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Explique o que precisa ser corrigido',
              hintText: 'Ex.: documento cortado, selfie escura ou dados ilegíveis.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Informe o motivo da revisão.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Enviar revisão'),
            ),
          ],
        ),
      );
      reviewNote = controller.text.trim();
      controller.dispose();
      if (confirmed != true) return;
    }

    try {
      final result = await supabase.rpc(
        'admin_set_worker_identity_status',
        params: {
          'p_worker_id': workerId,
          'p_status': status,
          'p_review_note': reviewNote.isEmpty ? null : reviewNote,
        },
      );

      final resultMap = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      final pioneerGrantedNow = resultMap['pioneer_granted'] == true;

      await createNotificationForUser(
        userId: workerId,
        title: status == 'verified'
            ? 'Identidade verificada'
            : status == 'rejected'
                ? 'Verificação precisa de revisão'
                : 'Verificação de identidade removida',
        body: status == 'verified'
            ? (pioneerGrantedNow
                ? 'Sua identidade foi conferida. Os selos Identidade verificada e Pioneiro PegaeFazFree estão ativos no seu perfil.'
                : 'Sua identidade foi conferida e o selo Identidade verificada está ativo no PegaeFazFree.')
            : status == 'rejected'
                ? 'Sua solicitação precisa de revisão: $reviewNote'
                : 'O selo de identidade verificada foi removido da sua conta.',
        referenceType: 'identity_verification',
        referenceId: workerId,
      );

      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar verificação: $e')),
      );
    }
  }

  Future<void> togglePioneer(Map<String, dynamic> worker) async {
    final workerId = (worker['id'] ?? '').toString();
    if (workerId.isEmpty) return;

    final current = trustFor(workerId);
    if (!current.identityVerified && !current.pioneerBadge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O selo Pioneiro só pode ser concedido depois da verificação de identidade.',
          ),
        ),
      );
      return;
    }

    final granting = !current.pioneerBadge;

    try {
      await supabase.rpc(
        'admin_set_pioneer_badge',
        params: {
          'p_worker_id': workerId,
          'p_enabled': granting,
        },
      );

      await createNotificationForUser(
        userId: workerId,
        title: granting
            ? 'Selo Pioneiro PegaeFazFree'
            : 'Selo Pioneiro removido',
        body: granting
            ? 'Você recebeu o selo Pioneiro PegaeFazFree, reconhecimento simbólico pela participação na fase inicial da plataforma.'
            : 'O selo Pioneiro PegaeFazFree foi removido da sua conta.',
        referenceType: 'pioneer_badge',
        referenceId: workerId,
      );

      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar selo Pioneiro: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestadores e verificação'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8DE),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5C14A)),
                    ),
                    child: const Text(
                      'Atenção: aprove a Identidade verificada somente depois de uma conferência real da identidade do prestador. A verificação financeira da conta de recebimento, sozinha, não deve ser tratada automaticamente como selo do PegaeFazFree. O selo confirma identidade, não garante qualidade ou conduta do serviço.',
                      style: TextStyle(
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pioneiros concedidos: $pioneerCount/100',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (workers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Nenhum prestador encontrado.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...workers.map((worker) {
                      final workerId = (worker['id'] ?? '').toString();
                      final name = displayProfileNameFromMap(
                        worker,
                        fallback: 'Prestador',
                      );
                      final city = (worker['city'] ?? '').toString();
                      final state = (worker['state'] ?? '').toString();
                      final specialty =
                          (worker['specialty'] ?? '').toString();
                      final workerCnpj =
                          (worker['worker_cnpj'] ?? '').toString();
                      final resume = resumesByWorkerId[workerId];
                      final trust = trustFor(workerId);
                      final evidence = evidenceFor(workerId);
                      final councilType =
                          (resume?['professional_council_type'] ?? '')
                              .toString();
                      final councilNumber =
                          (resume?['professional_council_number'] ?? '')
                              .toString();
                      final councilUf =
                          (resume?['professional_council_uf'] ?? '')
                              .toString();
                      final councilValidated =
                          resume?['professional_validated'] == true;

                      final statusColor = trust.identityVerified
                          ? Colors.green
                          : trust.pending
                              ? Colors.orange
                              : trust.status == 'rejected'
                                  ? Colors.redAccent
                                  : Colors.black54;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: trust.identityVerified
                                ? Colors.green.withOpacity(0.28)
                                : Colors.black12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      const Color(0xFFF4C61D),
                                  child: Text(
                                    displayProfileInitial(name),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                      if (specialty.isNotEmpty)
                                        Text(specialty),
                                      if (city.isNotEmpty || state.isNotEmpty)
                                        Text(
                                          '$city${state.isNotEmpty ? '/$state' : ''}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: Icon(
                                    trust.identityVerified
                                        ? Icons.verified_user
                                        : trust.pending
                                            ? Icons.hourglass_top
                                            : Icons.person_search_outlined,
                                    size: 17,
                                    color: statusColor,
                                  ),
                                  label: Text(trust.statusLabel),
                                ),
                                if (trust.pioneerBadge)
                                  const Chip(
                                    avatar: Icon(
                                      Icons.workspace_premium_outlined,
                                      size: 17,
                                    ),
                                    label: Text('Pioneiro PegaeFazFree'),
                                  ),
                              ],
                            ),
                            if (trust.requestedAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Solicitado em ${formatDate(trust.requestedAt)}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  evidence.hasRequiredFiles
                                      ? Icons.lock_person_outlined
                                      : Icons.no_accounts_outlined,
                                  size: 18,
                                  color: evidence.hasRequiredFiles
                                      ? Colors.green
                                      : Colors.black45,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    evidence.hasRequiredFiles
                                        ? 'Documento e selfie enviados • ${evidence.documentType}'
                                        : 'Documento e selfie ainda não enviados',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: evidence.hasRequiredFiles
                                          ? Colors.green
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (evidence.reviewNote.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Última orientação: ${evidence.reviewNote.trim()}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (workerCnpj.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'CNPJ informado: $workerCnpj',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (councilType.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Registro profissional: $councilType $councilNumber/$councilUf • ${councilValidated ? 'verificado' : 'pendente'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: councilValidated
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (evidence.hasRequiredFiles)
                                  OutlinedButton.icon(
                                    onPressed: () => showIdentityEvidence(worker),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('Ver documento e selfie'),
                                  ),
                                if (!trust.identityVerified)
                                  ElevatedButton.icon(
                                    onPressed: evidence.hasRequiredFiles
                                        ? () => setIdentityStatus(worker, 'verified')
                                        : null,
                                    icon: const Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                    label: const Text(
                                      'Aprovar identidade',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                if (trust.pending)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        setIdentityStatus(worker, 'rejected'),
                                    icon: const Icon(
                                      Icons.rule_folder_outlined,
                                    ),
                                    label: const Text('Pedir revisão'),
                                  ),
                                if (trust.identityVerified)
                                  OutlinedButton.icon(
                                    onPressed: () => setIdentityStatus(
                                      worker,
                                      'not_requested',
                                    ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    label: const Text(
                                      'Remover verificação',
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => togglePioneer(worker),
                                  icon: Icon(
                                    trust.pioneerBadge
                                        ? Icons.workspace_premium
                                        : Icons.workspace_premium_outlined,
                                  ),
                                  label: Text(
                                    trust.pioneerBadge
                                        ? 'Remover Pioneiro'
                                        : 'Conceder Pioneiro',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  bool loading = true;
  List<JobModel> jobs = [];
  String filter = 'all';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      jobs = (await supabase.from('jobs').select().order('created_at', ascending: false) as List)
          .map((e) => JobModel.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) { jobs = []; }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = jobs.where((j) => filter == 'all' ? true : j.status == filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Ordens de serviço e disputas')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, children: ['all','open','proposal_sent','in_progress','done','cancelled'].map((f) => ChoiceChip(label: Text(f == 'all' ? 'Todos' : f), selected: filter == f, onSelected: (_) => setState(() => filter = f))).toList()),
          const SizedBox(height: 12),
          ...filtered.map((job) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(job.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Status: ${statusLabel(job.status)}'),
              Text('Pagamento: ${paymentStatusLabel(job.paymentStatus)}'),
              Text('Repasse: ${escrowStatusLabel(job.escrowStatus)}'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () async { await supabase.from('jobs').update({'status': 'cancelled'}).eq('id', job.id); await load(); }, child: const Text('Cancelar')),
                OutlinedButton(onPressed: () async { await supabase.from('jobs').update({'status': 'in_progress'}).eq('id', job.id); await load(); }, child: const Text('Marcar andamento')),
                OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(jobId: job.id, jobTitle: job.title))), child: const Text('Log de conversas')),
              ])
            ]),
          )),
        ],
      ),
    );
  }
}

class AdminCommissionsPage extends StatefulWidget {
  const AdminCommissionsPage({super.key});

  @override
  State<AdminCommissionsPage> createState() => _AdminCommissionsPageState();
}


class _AdminCommissionsPageState extends State<AdminCommissionsPage> {
  bool loading = true;
  List<JobModel> jobs = [];
  Map<String, Map<String, dynamic>> paymentSnapshotByJob = {};
  double feePercent = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    feePercent = await getEffectivePlatformFeePercent();
    try {
      jobs = (await supabase
              .from('jobs')
              .select()
              .order('created_at', ascending: false) as List)
          .map(
            (e) => JobModel.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      await refreshAllVisiblePayments(jobs);

      final paymentRows = (await supabase
              .from('payments')
              .select(
                'job_id,amount,service_amount,status,provider,platform_fee,platform_fee_amount,worker_net_amount,currency,created_at',
              )
              .eq('provider', 'stripe')
              .order('created_at', ascending: false) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      paymentSnapshotByJob = {};

      for (final row in paymentRows) {
        final jobId = (row['job_id'] ?? '').toString();
        if (jobId.isEmpty) continue;

        // Como a consulta já vem do mais novo para o mais antigo,
        // preserva o primeiro registro encontrado de cada serviço.
        paymentSnapshotByJob.putIfAbsent(
          jobId,
          () => row,
        );
      }
    } catch (_) {
      jobs = [];
      paymentSnapshotByJob = {};
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> changeFeePercent() async {
    final controller = TextEditingController(
      text: feePercent.toStringAsFixed(
        feePercent == feePercent.roundToDouble() ? 0 : 2,
      ),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alterar taxa da plataforma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A nova taxa será aplicada aos próximos pagamentos. '
              'Pagamentos já iniciados ou concluídos mantêm os valores que foram '
              'salvos no momento da cobrança.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Taxa da plataforma',
                hintText: 'Ex.: 0, 1, 2.5, 5 ou 10',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (value == null || value < 0 || value > 50) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe uma taxa entre 0% e 50%.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4C61D),
              foregroundColor: Colors.black,
            ),
            child: const Text('Salvar taxa'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) return;

    final previousFee = feePercent;

    try {
      final settings = await getAppSettings();

      if (settings != null && settings['id'] != null) {
        await supabase
            .from('app_settings')
            .update({
              'platform_fee_percent': result,
            })
            .eq('id', settings['id']);
      } else {
        await supabase.from('app_settings').insert({
          'platform_fee_percent': result,
        });
      }

      final savedFee = await getEffectivePlatformFeePercent();

      if (!mounted) return;

      setState(() {
        feePercent = savedFee;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Taxa da plataforma atualizada para '
            '${savedFee.toStringAsFixed(savedFee == savedFee.roundToDouble() ? 0 : 2)}%. '
            'Os próximos pagamentos já usarão esse percentual.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        feePercent = previousFee;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível salvar a taxa no servidor: $e',
          ),
        ),
      );
    }
  }

  Future<void> copyReport(double gross, double commission, double payout) async {
    final report = 'Relatório PegaeFazFree\n'
        'Faturamento bruto: ${money(gross)}\n'
        'Taxa da plataforma já registrada nos pagamentos: ${money(commission)}\n''Taxa atual para novos pagamentos: ${feePercent.toStringAsFixed(2)}%\n'
        'Repasse estimado aos prestadores: ${money(payout)}\n'
        'Serviços pagos: ${jobs.where((j) => j.paymentStatus == 'paid').length}';
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Relatório copiado.')),
    );
  }

  Future<void> simulatePayout(JobModel job) async {
    final commission = job.price * (feePercent / 100);
    final payout = job.price - commission;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Simulação para novo pagamento'),
        content: Text(
          'Serviço: ${job.title}\n\n'
          'Valor bruto: ${money(job.price)}\n'
          'Taxa da plataforma: ${money(commission)}\n'
          'Prestador recebe: ${money(payout)}\n\n'
          'Esta simulação usa a taxa atualmente configurada. Pagamentos já realizados preservam os valores salvos na cobrança. O repasse financeiro real é executado pelo backend seguro do PegaeFazFree.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Future<void> syncJob(JobModel job) async {
    await syncJobPaymentStatus(job.id);
    await load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pagamento sincronizado.')),
    );
  }

  void openJob(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailsPage(job: job, onChanged: load, adminMode: true)),
    );
  }

  double _paymentValue(
    Map<String, dynamic>? payment,
    String primary, {
    String? fallback,
    double defaultValue = 0,
  }) {
    final raw = payment?[primary] ??
        (fallback == null ? null : payment?[fallback]);

    if (raw is num) return raw.toDouble();

    return double.tryParse(
          raw?.toString().replaceAll(',', '.') ?? '',
        ) ??
        defaultValue;
  }

  double _grossForJob(JobModel job) {
    final payment = paymentSnapshotByJob[job.id];
    return _paymentValue(
      payment,
      'service_amount',
      fallback: 'amount',
      defaultValue: job.price,
    );
  }

  double _feeForJob(JobModel job) {
    final payment = paymentSnapshotByJob[job.id];

    if (payment != null) {
      return _paymentValue(
        payment,
        'platform_fee_amount',
        fallback: 'platform_fee',
      );
    }

    // Apenas compatibilidade com registros antigos sem snapshot.
    return calculatePlatformFee(
      job.price,
      feePercent: feePercent,
    );
  }

  double _workerNetForJob(JobModel job) {
    final payment = paymentSnapshotByJob[job.id];

    if (payment != null) {
      final saved = _paymentValue(
        payment,
        'worker_net_amount',
      );
      if (saved > 0) return saved;
    }

    return _grossForJob(job) - _feeForJob(job);
  }

  @override
  Widget build(BuildContext context) {
    final paidJobs = jobs.where((j) => j.paymentStatus == 'paid').toList();
    final pendingJobs = jobs.where((j) => j.paymentStatus == 'pending').toList();

    final gross = paidJobs.fold<double>(
      0,
      (sum, job) => sum + _grossForJob(job),
    );

    final platformFees = paidJobs.fold<double>(
      0,
      (sum, job) => sum + _feeForJob(job),
    );

    final payout = paidJobs.fold<double>(
      0,
      (sum, job) => sum + _workerNetForJob(job),
    );

    final chartValues = [gross, platformFees, payout];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxas e repasses'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF4C61D), foregroundColor: Colors.black),
                    ),
                    OutlinedButton.icon(
                      onPressed: changeFeePercent,
                      icon: const Icon(Icons.percent),
                      label: const Text('Alterar taxa'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => copyReport(gross, platformFees, payout),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar relatório'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    PffMetricCard(title: 'Faturamento bruto', value: money(gross), icon: Icons.payments_outlined),
                    PffMetricCard(title: 'Taxa da plataforma', value: money(platformFees), icon: Icons.pie_chart_outline),
                    PffMetricCard(title: 'Repasses', value: money(payout), icon: Icons.account_balance_wallet_outlined),
                    PffMetricCard(title: 'Pagos', value: '${paidJobs.length}', icon: Icons.check_circle_outline),
                    PffMetricCard(title: 'Pendentes', value: '${pendingJobs.length}', icon: Icons.hourglass_empty),
                    PffMetricCard(title: 'Taxa atual', value: '${feePercent.toStringAsFixed(1)}%', icon: Icons.percent),
                  ],
                ),
                const SizedBox(height: 12),
                PffDashboardBarChart(
                  title: 'Distribuição financeira estimada',
                  labels: const ['Bruto', 'Taxa', 'Repasse'],
                  values: chartValues,
                  moneyValues: true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: const Text(
                    'A taxa definida aqui é salva no servidor e vale para novos pagamentos. Cada cobrança guarda seu próprio valor de taxa e líquido do prestador, evitando que uma alteração futura mude pagamentos já realizados. O repasse real é executado somente pelo backend seguro do PegaeFazFree.',
                    style: TextStyle(color: Colors.black54, height: 1.35, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Serviços pagos e repasses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (paidJobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    child: const Text('Nenhum serviço pago encontrado ainda.'),
                  )
                else
                  ...paidJobs.take(50).map((job) {
                    final grossValue = _grossForJob(job);
                    final commissionValue = _feeForJob(job);
                    final workerValue = _workerNetForJob(job);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('Bruto: ${money(grossValue)}'),
                          Text('Taxa da plataforma: ${money(commissionValue)}'),
                          Text('Prestador recebe: ${money(workerValue)}'),
                          Text('Repasse: ${escrowStatusLabel(job.escrowStatus)}'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => simulatePayout(job),
                                icon: const Icon(Icons.calculate_outlined),
                                label: const Text('Simular repasse'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => syncJob(job),
                                icon: const Icon(Icons.sync),
                                label: const Text('Sincronizar'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => openJob(job),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Abrir serviço'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF4C61D), foregroundColor: Colors.black),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class AdminLocationIntelligencePage extends StatefulWidget {
  const AdminLocationIntelligencePage({super.key});

  @override
  State<AdminLocationIntelligencePage> createState() => _AdminLocationIntelligencePageState();
}

class _AdminLocationIntelligencePageState extends State<AdminLocationIntelligencePage> {
  bool loading = true;
  Map<String, int> demandByLocation = {};
  Map<String, int> supplyByCity = {};

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final jobs = (await supabase.from('jobs').select('location') as List).map((e) => Map<String, dynamic>.from(e));
      demandByLocation = {};
      for (final item in jobs) {
        final k = (item['location'] ?? 'Não informado').toString();
        demandByLocation[k] = (demandByLocation[k] ?? 0) + 1;
      }
    } catch (_) { demandByLocation = {}; }
    try {
      final resumes = (await supabase.from('worker_resumes').select('city') as List).map((e) => Map<String, dynamic>.from(e));
      supplyByCity = {};
      for (final item in resumes) {
        final k = (item['city'] ?? 'Não informado').toString();
        supplyByCity[k] = (supplyByCity[k] ?? 0) + 1;
      }
    } catch (_) { supplyByCity = {}; }
    if (mounted) setState(() => loading = false);
  }

  Widget _mapList(String title, Map<String,int> data) {
    final entries = data.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          if (entries.isEmpty) const Text('Sem dados ainda.') else ...entries.take(10).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${e.key}: ${e.value}'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final demandEntries = demandByLocation.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    final supplyEntries = supplyByCity.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: const Text('Inteligência de localização')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: const Text('Resumo tático de demanda e oferta. O heatmap visual real e o ajuste persistente de raio entram na próxima entrega com SQL e backend.', style: TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Maior demanda por região', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              if (demandEntries.isEmpty) const Text('Sem dados ainda.') else ...demandEntries.take(10).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${e.key}: ${e.value} pedido(s)'))),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Oferta de prestadores por cidade', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              if (supplyEntries.isEmpty) const Text('Sem dados ainda.') else ...supplyEntries.take(10).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${e.key}: ${e.value} prestador(es)'))),
            ]),
          ),
        ],
      ),
    );
  }
}

class AdminReputationPage extends StatefulWidget {
  const AdminReputationPage({super.key});

  @override
  State<AdminReputationPage> createState() => _AdminReputationPageState();
}

class _AdminReputationPageState extends State<AdminReputationPage> {
  bool loading = true;
  List<WorkerRankingEntry> ranking = [];

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { setState(() => loading = true); ranking = await loadWorkerRanking(); if (mounted) setState(() => loading = false); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reputação e qualidade')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Ranking de performance', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 12),
          ...ranking.take(20).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                CircleAvatar(backgroundColor: const Color(0xFFF4C61D), child: Text('${i+1}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(item.specialty),
                  Text('Média ${item.averageRating.toStringAsFixed(1)} • ${item.reviewsCount} avaliações • ${item.completedJobs} concluídos'),
                ])),
              ]),
            );
          }),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsPage(adminMode: true))), icon: const Icon(Icons.star_outline), label: const Text('Abrir moderação de avaliações')),
        ],
      ),
    );
  }
}

class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({super.key});

  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  bool loading = true;
  List<JobModel> jobs = [];

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() => loading = true);
    try { jobs = (await supabase.from('jobs').select().order('created_at', ascending: false) as List).map((e)=>JobModel.fromMap(Map<String,dynamic>.from(e))).toList(); } catch (_) { jobs = []; }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking, agenda e check-in')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: const Text('Nesta entrega, o ADM ganha visão tática para pedidos diretos, agenda operacional, urgência e taxa de aceitação. Check-in GPS real entra junto do backend na próxima fase.', style: TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 12),
          ...jobs.take(20).map((job) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(job.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Status: ${statusLabel(job.status)}'),
              Text('Local: ${job.publicLocationLabel}'),
              Text('Agendamento: ${formatDate(job.createdAt)}'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () async { await supabase.from('jobs').update({'status':'in_progress'}).eq('id', job.id); await load(); }, child: const Text('Forçar check-in')),
                OutlinedButton(onPressed: () async { await supabase.from('jobs').update({'status':'done'}).eq('id', job.id); await load(); }, child: const Text('Forçar check-out')),
              ]),
            ]),
          )),
        ],
      ),
    );
  }
}

class AdminRulesEnginePage extends StatefulWidget {
  const AdminRulesEnginePage({super.key});

  @override
  State<AdminRulesEnginePage> createState() => _AdminRulesEnginePageState();
}

class _AdminRulesEnginePageState extends State<AdminRulesEnginePage> {
  bool loading = true;
  double feePercent = 0;

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { feePercent = await getEffectivePlatformFeePercent(); if (mounted) setState(() => loading = false); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Motor de regras do ADM')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Modelos híbridos por categoria', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              SizedBox(height: 8),
              Text('Use orçamento/leilão para serviços complexos e booking direto para atendimentos rápidos. Nesta entrega, a tela administrativa fica pronta para gestão manual. Persistência total entra com SQL dedicado.'),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Comissionamento e preço dinâmico', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Taxa atual da plataforma: ${feePercent.toStringAsFixed(0)}%'),
              const SizedBox(height: 8),
              const Text('Filtros prontos para urgência, modelo de atendimento, preço base por categoria e raio operacional.'),
            ]),
          ),
        ],
      ),
    );
  }
}

class AdminSpamPage extends StatefulWidget {
  const AdminSpamPage({super.key});

  @override
  State<AdminSpamPage> createState() => _AdminSpamPageState();
}

class _AdminSpamPageState extends State<AdminSpamPage> {
  bool loading = true;
  List<Map<String, dynamic>> alerts = [];
  List<Map<String, dynamic>> blockedUsers = [];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { alerts = (await supabase.from('safety_events').select().order('created_at', ascending: false) as List).map((e)=>Map<String,dynamic>.from(e)).toList(); } catch (_) { alerts = []; }
    try {
      blockedUsers = (await supabase
              .from('profiles')
              .select('id,name,warning_count,is_blocked')
              .eq('is_blocked', true) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => !isDeletedProfileMap(e))
          .toList();
    } catch (_) {
      blockedUsers = [];
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spam, fraude e pedidos falsos')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _AdminSectionTitle('Fila suspeita'),
          ...alerts.take(20).map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: item['blocked'] == true ? Colors.redAccent : Colors.orangeAccent)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((item['reason'] ?? 'Evento').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text((item['content'] ?? '').toString()),
              const SizedBox(height: 8),
              Text('Origem: ${(item['source_type'] ?? '').toString()} • ${(item['source_id'] ?? '').toString()}', style: const TextStyle(color: Colors.black54)),
            ]),
          )),
          const SizedBox(height: 12),
          const _AdminSectionTitle('Usuários bloqueados'),
          ...blockedUsers.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((item['name'] ?? 'Usuário').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('Warnings: ${(item['warning_count'] ?? 0).toString()}'),
              ])),
              OutlinedButton(onPressed: () async { await supabase.from('profiles').update({'is_blocked': false}).eq('id', item['id']); await load(); }, child: const Text('Desbloquear')),
            ]),
          )),
        ],
      ),
    );
  }
}

class _AdminSectionTitle extends StatelessWidget {
  final String title;
  const _AdminSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
    );
  }
}

class _AdminFinanceSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  const _AdminFinanceSummaryCard({required this.title, required this.value, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ]),
    );
  }
}

const String privacyText = '''
Resumo rápido

O PegaeFazFree trata dados para permitir cadastro, conexão entre usuários, pagamentos, localização, comunicação, notificações, segurança, suporte e demais funcionalidades da plataforma.

• Coletamos somente informações relacionadas ao funcionamento, segurança e evolução da plataforma.

• Dados podem ser compartilhados com outros usuários quando isso fizer parte da própria funcionalidade do serviço.

• Pagamentos e verificações financeiras podem envolver provedores especializados, como Stripe e Google Play, conforme o caso.

• O PegaeFazFree não comercializa dados pessoais como produto nem transfere sua propriedade a terceiros. Algumas funcionalidades podem oferecer acesso controlado a informações disponibilizadas pelo próprio usuário, como currículos, conforme a finalidade do recurso e as regras desta Política.

• O usuário pode exercer direitos previstos na LGPD, inclusive correção e, quando aplicável, exclusão dos dados.

1. Quem é responsável pelo tratamento

Para as atividades descritas nesta Política, o PegaeFazFree atua como responsável pelas decisões essenciais relacionadas ao tratamento dos dados pessoais utilizados para operar sua plataforma, sem prejuízo das responsabilidades próprias de provedores terceiros que também atuem como controladores independentes em determinadas operações.

Solicitações relacionadas à privacidade podem ser encaminhadas pelos canais oficiais disponíveis na página de contato do PegaeFazFree.

2. Dados que podemos coletar

Os dados tratados variam conforme o tipo de perfil, as funcionalidades utilizadas e as permissões concedidas pelo usuário.

• Dados de cadastro e identificação, como nome, e-mail, telefone, cidade, tipo de perfil e demais informações fornecidas no cadastro.

• Dados profissionais e empresariais, como especialidades, descrição profissional, currículo, experiências, formação, informações da empresa, documentos e informações cadastrais quando necessários. Currículos e seus conteúdos podem constituir dados pessoais e serão tratados conforme a finalidade para a qual forem disponibilizados.

• Dados relacionados aos serviços, como solicitações, propostas, contrapropostas, valores, status, local do serviço, fotos, comprovantes de conclusão e avaliações.

• Mensagens e interações realizadas pelo chat ou por recursos de suporte e denúncia.

• Localização aproximada, localização informada pelo usuário e localização relacionada a um serviço, quando necessária para a funcionalidade utilizada.

• Dados técnicos, como identificadores internos, versão do aplicativo, registros de acesso, eventos de segurança e tokens utilizados para notificações push.

• Dados de pagamento e transação recebidos de provedores financeiros, como identificadores da cobrança, status, valor, moeda, identificadores de repasse, reembolso, contestação e outras informações necessárias para acompanhar a operação.

• Informações de compra relacionadas a funcionalidades digitais, quando adquiridas por loja de aplicativos ou outro meio de faturamento permitido.

3. Dados financeiros e pagamentos

Nos pagamentos de serviços realizados pelo fluxo oficial, o processamento financeiro poderá ser feito por provedores especializados, como a Stripe. O prestador também poderá realizar cadastro e verificações exigidas pelo provedor para habilitar sua conta conectada e receber repasses.

O PegaeFazFree pode receber e armazenar identificadores e informações operacionais da transação, como status de pagamento, valor, identificador de Checkout, Payment Intent, cobrança, transferência, reembolso, contestação e conta conectada, quando necessários para controlar o fluxo financeiro e prestar suporte.

Quando uma compra digital for processada pelo Google Play ou por outro sistema de faturamento permitido, o PegaeFazFree poderá tratar identificadores de compra, produto, situação da compra, período de acesso e outras informações necessárias para liberar, renovar, bloquear ou restaurar a funcionalidade adquirida.

4. Verificação de identidade e cadastro financeiro

Algumas funcionalidades, especialmente o recebimento de valores por prestadores, podem depender de verificações de identidade, cadastro, CPF, CNPJ, dados bancários, documentos ou outras informações exigidas pelo provedor financeiro.

A verificação de identidade do selo PegaeFazFree é separada da verificação financeira. Quando o prestador solicita o selo “Identidade verificada”, a plataforma pode coletar uma imagem de documento oficial com foto, como RG/CIN ou CNH, e uma selfie capturada pelo aplicativo. Esses arquivos são utilizados para conferência de identidade, prevenção a fraude, segurança e análise da solicitação.

Os arquivos enviados para o selo são mantidos em armazenamento privado e não são exibidos publicamente a clientes, empresas ou outros prestadores. O acesso é restrito ao próprio titular e às pessoas autorizadas pela administração do PegaeFazFree para executar a análise, observadas as regras de segurança e necessidade de acesso.

No fluxo de conta conectada utilizado pelo PegaeFazFree, o cadastro financeiro e a coleta das informações e documentos exigidos para verificação são realizados diretamente no ambiente de onboarding hospedado pela Stripe. Esses dados são fornecidos pelo titular diretamente à Stripe, de acordo com os requisitos aplicáveis à conta, ao país, ao tipo de pessoa ou empresa e às funcionalidades financeiras solicitadas.

Os documentos enviados à Stripe permanecem no fluxo do provedor financeiro e são distintos dos arquivos que o prestador eventualmente envie ao PegaeFazFree para solicitar o selo de identidade. Para operar a integração financeira, a plataforma poderá receber da Stripe identificadores da conta conectada, situação do cadastro, requisitos pendentes, status de verificação, habilitação para receber repasses e outras informações operacionais necessárias para determinar se a conta está apta a utilizar os recursos financeiros.

5. Para que usamos os dados

Os dados podem ser utilizados, conforme necessário e compatível com a funcionalidade utilizada, para:

• Criar, autenticar, proteger e manter contas de usuários.

• Conectar clientes, prestadores e empresas.

• Permitir publicação de serviços, propostas, contrapropostas, chat, avaliações e currículos.

• Processar, acompanhar e conciliar pagamentos, repasses, reembolsos e contestações.

• Confirmar conclusão de serviços e preservar registros relacionados à contratação.

• Enviar notificações sobre mensagens, propostas, serviços, pagamentos, segurança e outras atividades relevantes.

• Oferecer recursos baseados em localização, quando autorizados ou informados pelo usuário.

• Prevenir fraude, abuso, spam, acesso indevido e outras situações de risco.

• Atender solicitações de suporte, denúncias, disputas e pedidos relacionados à privacidade.

• Cumprir obrigações legais, regulatórias e determinações de autoridades competentes.

• Melhorar desempenho, estabilidade, usabilidade, segurança e funcionalidades da plataforma.

6. Bases legais

Dependendo da finalidade e da situação concreta, o tratamento de dados poderá se apoiar nas bases legais previstas na legislação aplicável, incluindo execução de contrato ou procedimentos relacionados à contratação, cumprimento de obrigação legal ou regulatória, exercício regular de direitos, prevenção à fraude e segurança, legítimo interesse e consentimento quando ele for necessário.

Quando uma funcionalidade depender de consentimento ou permissão do dispositivo, o usuário poderá ter mecanismos para conceder ou revogar essa autorização, observadas as limitações técnicas e legais aplicáveis.

7. Compartilhamento entre usuários

Alguns dados são compartilhados porque isso faz parte do próprio funcionamento do marketplace.

• Clientes e prestadores podem visualizar informações necessárias para avaliar, propor, contratar e executar um serviço.

• Dados como nome de perfil, descrição profissional, avaliações e informações relacionadas ao serviço podem ficar visíveis às partes envolvidas.

• Empresas com acesso válido ao recurso de currículos podem visualizar somente currículos disponibilizados por prestadores para essa finalidade, conforme as regras de acesso da plataforma.

• Currículos contêm dados pessoais e profissionais. O prestador deve disponibilizá-los de forma consciente para finalidades relacionadas a oportunidades profissionais, recrutamento e contratação.

• A cobrança realizada da empresa refere-se ao acesso temporário à funcionalidade de consulta disponibilizada pelo PegaeFazFree. Ela não representa compra, cessão, venda ou transferência de propriedade sobre os dados pessoais contidos nos currículos.

• O acesso empresarial é limitado à finalidade informada pela plataforma. É proibida a revenda, comercialização, publicação, distribuição em massa, formação de banco de dados paralelo ou utilização dos currículos para finalidade incompatível com o recurso.

• Dados financeiros sensíveis, documentos de identificação e informações que não sejam necessárias à contratação não devem ser exibidos publicamente.

8. Compartilhamento com fornecedores e parceiros tecnológicos

O PegaeFazFree pode utilizar fornecedores de tecnologia para operar recursos essenciais da plataforma. O compartilhamento ocorre na medida necessária à prestação do serviço correspondente.

• Supabase ou infraestrutura equivalente para autenticação, banco de dados, armazenamento e recursos de backend.

• Firebase e serviços Google relacionados a notificações, funcionamento do aplicativo e recursos compatíveis.

• Stripe e empresas relacionadas para processamento de pagamentos, contas conectadas, verificação, prevenção de fraude, repasses e reembolsos.

• Google Play e outros canais de distribuição ou faturamento quando uma compra ou funcionalidade for processada por esses canais.

• Prestadores de infraestrutura, hospedagem, segurança e suporte necessários à operação da plataforma.

Esses terceiros podem possuir políticas próprias e, em determinadas atividades, tratar dados como controladores independentes conforme suas responsabilidades legais e contratuais.

9. Chat, denúncias, moderação e segurança

Mensagens e interações dentro da plataforma podem ser utilizadas para funcionamento do serviço, suporte, prevenção de fraude, análise de denúncias, investigação de incidentes e segurança.

• O chat ajuda a manter histórico do que foi conversado e combinado.

• Comportamentos suspeitos podem gerar alertas ou análise de segurança.

• Denúncias, disputas e conflitos podem exigir análise de mensagens, propostas, pagamentos, fotos, comprovantes e outros registros pertinentes.

• O acesso interno a essas informações deve ocorrer somente quando necessário para as finalidades previstas nesta Política.

10. Localização, câmera, fotos e arquivos

Quando o usuário permite ou informa dados de localização, essas informações podem ser usadas para encontrar serviços, profissionais, oportunidades próximas ou iniciar rotas relacionadas ao atendimento.

A câmera, a galeria e os arquivos do dispositivo podem ser utilizados, conforme a funcionalidade e mediante ação ou permissão do usuário. Fotos de serviço e comprovantes de conclusão podem exigir captura pela câmera no momento do uso; a galeria pode permanecer disponível em recursos específicos, como foto de perfil ou seleção de arquivos. Na verificação de identidade do prestador, o aplicativo pode utilizar a câmera para fotografar o documento e capturar a selfie destinada à análise do selo.

O usuário pode controlar permissões do dispositivo pelas configurações do sistema operacional, embora a revogação de uma permissão possa impedir o funcionamento de recursos que dependam dela.

11. Notificações

Para enviar notificações push, o aplicativo pode registrar tokens de dispositivo vinculados à conta do usuário e utilizá-los para avisos de mensagens, propostas, serviços, pagamentos, segurança e outras atividades relevantes.

O usuário pode controlar permissões de notificação pelas configurações do dispositivo, sem prejuízo de comunicações obrigatórias que precisem ocorrer por outro canal permitido.

12. Biometria e autenticação no dispositivo

Quando houver opção de acesso protegido por biometria, a validação é realizada pelos mecanismos de segurança do próprio sistema operacional do dispositivo. O PegaeFazFree não precisa receber ou armazenar a impressão digital ou o modelo facial bruto utilizado pelo aparelho para essa autenticação local.

13. Retenção dos dados

Os dados são mantidos pelo tempo necessário para cumprir as finalidades desta Política e as obrigações relacionadas ao funcionamento da plataforma.

• Dados de conta e perfil podem ser mantidos enquanto a conta estiver ativa.

• Documentos e selfies enviados para verificação de identidade são mantidos apenas enquanto forem necessários para análise, segurança, prevenção a fraude, auditoria ou exercício regular de direitos. O acesso permanece restrito e os arquivos podem ser eliminados quando deixarem de ser necessários, observadas as hipóteses legais de retenção.

• Registros de serviços, mensagens, pagamentos, repasses, reembolsos, avaliações, denúncias e segurança podem ser preservados por período adicional quando necessários para suporte, prevenção à fraude, exercício regular de direitos, cumprimento de obrigação legal ou resolução de disputas.

• Dados em cópias de segurança podem permanecer temporariamente até serem substituídos ou eliminados conforme os ciclos técnicos de backup.

• Quando não houver mais finalidade ou fundamento para retenção, os dados poderão ser eliminados ou anonimizados, conforme aplicável.

14. Exclusão da conta e dos dados

O usuário poderá solicitar a exclusão da conta pelos recursos disponibilizados no aplicativo ou pelos canais oficiais indicados pelo PegaeFazFree.

A exclusão da conta não significa necessariamente eliminação imediata de todo e qualquer registro. Informações que precisem ser mantidas para cumprimento de obrigação legal, prevenção à fraude, exercício regular de direitos, segurança, disputas ou outras hipóteses permitidas pela legislação poderão ser preservadas pelo período necessário.

Dados que não precisem mais ser mantidos serão eliminados ou anonimizados de acordo com os procedimentos técnicos e legais aplicáveis.

15. Segurança dos dados

O PegaeFazFree adota medidas técnicas e administrativas destinadas a proteger dados contra acessos não autorizados, perda, alteração indevida, divulgação e outras situações de risco.

Mesmo com medidas de proteção, nenhum ambiente digital é totalmente imune a incidentes. Por isso, o usuário também deve proteger sua conta, dispositivo, senha e códigos de autenticação e evitar o compartilhamento de informações sensíveis por canais não confiáveis.

16. Direitos do titular

Nos termos da legislação aplicável, o titular pode apresentar solicitações relacionadas aos seus dados pessoais pelos canais oficiais do PegaeFazFree.

• Confirmar a existência de tratamento de dados pessoais.

• Solicitar acesso aos dados, observadas as regras e limitações aplicáveis.

• Solicitar correção de dados incompletos, inexatos ou desatualizados.

• Solicitar informações sobre compartilhamentos realizados.

• Solicitar anonimização, bloqueio ou eliminação quando cabível.

• Revogar consentimento quando o tratamento depender dessa base legal.

• Solicitar exclusão da conta e dos dados associados, respeitadas as hipóteses legais de retenção.

• Apresentar outras solicitações previstas na LGPD e na legislação aplicável.

17. Transferência e armazenamento de dados

Alguns fornecedores tecnológicos utilizados pelo PegaeFazFree podem operar infraestrutura ou processar informações em diferentes localidades. Quando houver tratamento ou transferência internacional de dados, serão observadas as exigências legais aplicáveis e as medidas de proteção compatíveis com a atividade realizada.

18. Alterações desta Política

Esta Política de Privacidade poderá ser atualizada para refletir alterações no aplicativo, novos recursos, meios de pagamento, fornecedores, práticas de segurança ou adequações legais. A versão vigente permanecerá disponível nesta página.

Última atualização: outubro de 2026.

Transparência

Explicamos quais dados são utilizados, para quais finalidades e com quem podem ser compartilhados.

Segurança

Dados de cadastro, serviços e pagamentos são tratados de acordo com a finalidade de cada recurso.

Controle

O usuário pode exercer direitos sobre seus dados e solicitar exclusão da conta, observadas as retenções legalmente necessárias.

Dúvidas ou solicitações sobre privacidade?

Entre em contato pelos canais oficiais do PegaeFazFree para solicitar informações, correções, exclusão ou orientação sobre seus dados.
''';

const String termsText = '''
Resumo rápido

O PegaeFazFree conecta clientes, prestadores de serviços e empresas, oferecendo recursos para publicação de demandas, propostas, comunicação, pagamento, acompanhamento e reputação.

• Use informações verdadeiras e mantenha seus dados atualizados.

• Combine escopo, preço, prazo e demais condições importantes dentro da plataforma.

• Quando houver pagamento oficial no PegaeFazFree, utilize esse fluxo para preservar o histórico da operação.

• O pagamento de serviços pode ser processado pela Stripe e o repasse ao prestador ocorre em etapa separada, conforme as regras abaixo.

• Condutas abusivas, fraudulentas, ilegais ou inseguras podem gerar limitação ou bloqueio da conta.

1. Aceitação dos termos

Ao acessar, criar uma conta ou utilizar o PegaeFazFree, o usuário declara que leu, compreendeu e concorda com estes Termos de Uso, com a Política de Privacidade e com as orientações de Proteção do Usuário disponibilizadas no site e no aplicativo.

Caso o usuário não concorde com estas condições, deverá deixar de utilizar as funcionalidades correspondentes da plataforma.

2. Sobre o PegaeFazFree

O PegaeFazFree é uma plataforma digital destinada a aproximar clientes, prestadores de serviços e empresas. Entre suas funcionalidades podem estar a publicação de demandas, busca de oportunidades, envio e contraproposta de valores, chat, acompanhamento do serviço, pagamentos, comprovação de conclusão, avaliações, currículos e recursos administrativos.

3. Contas, cadastro e responsabilidade pelas informações

O usuário deve fornecer informações verdadeiras, manter seus dados atualizados e proteger o acesso à própria conta.

• É proibido criar conta com dados falsos, usar documentos de terceiros sem autorização ou se passar por outra pessoa.

• O usuário é responsável por manter senha, e-mail, dispositivo e demais meios de acesso em segurança.

• Contas podem ser analisadas, limitadas, suspensas ou bloqueadas em caso de risco, abuso, fraude, violação destes termos ou exigência legal.

• Prestadores e empresas devem manter informações compatíveis com a atividade efetivamente exercida.

• Quando necessário para segurança, pagamentos ou conformidade, poderão ser solicitadas validações adicionais de identidade ou cadastro.

• O selo “Identidade verificada” indica que houve conferência de identidade conforme o procedimento adotado pela plataforma. O selo não representa garantia de qualidade, idoneidade, conduta, habilitação técnica ou resultado do serviço.

• Para solicitar esse selo, o prestador poderá precisar enviar documento oficial com foto e selfie pelo aplicativo. Esses arquivos são destinados à análise de identidade e segurança, permanecem privados e não integram o perfil público do prestador.

• O selo “Pioneiro PegaeFazFree” é um reconhecimento simbólico destinado a participantes da fase inicial da plataforma. Ele não concede participação societária, quotas, direito a lucros, propriedade da empresa, vínculo trabalhista ou poder para representar o PegaeFazFree.

• Validações de conselhos profissionais, quando aplicáveis, são distintas da verificação geral de identidade e podem possuir status próprio.

4. Serviços, propostas, contrapropostas e chat

Clientes podem publicar solicitações de serviços, prestadores podem enviar propostas e as partes podem utilizar o chat para alinhar os detalhes da contratação.

• As propostas devem ser claras, honestas e compatíveis com o serviço solicitado.

• As partes devem definir, sempre que aplicável, escopo, valor, prazo, local, materiais, deslocamento e demais condições relevantes.

• Propostas e contrapropostas aceitas podem ser utilizadas como referência do que foi combinado entre as partes.

• O chat e os registros da plataforma podem auxiliar no suporte, na apuração de ocorrências e na análise de disputas.

• É proibido utilizar o chat para golpes, ameaças, assédio, discriminação, spam, atividades ilegais ou tentativa de burlar mecanismos de segurança da plataforma.

5. Pagamento de serviços pela plataforma

Quando o pagamento oficial estiver disponível para determinado serviço, o cliente poderá realizar o pagamento pelo fluxo apresentado no PegaeFazFree. O processamento financeiro dos pagamentos de serviços poderá ser realizado pela Stripe e por suas soluções de pagamento e conexão de contas.

Após a confirmação do pagamento pelo provedor financeiro, o PegaeFazFree poderá registrar o serviço como pago. A confirmação de pagamento não significa, por si só, que o valor destinado ao prestador já tenha sido transferido para a conta conectada dele.

• O cliente deve conferir valor, serviço e demais informações antes de confirmar o pagamento.

• Pagamentos podem depender de análise, autenticação, aprovação do meio de pagamento e regras do provedor financeiro.

• O prestador poderá precisar concluir o cadastro financeiro e as verificações exigidas pelo provedor antes de estar apto a receber repasses.

• O status exibido no PegaeFazFree poderá ser atualizado por confirmação automática do provedor ou por sincronização do pagamento.

6. Pagamento acompanhado e repasse ao prestador

Nos serviços compatíveis com o fluxo financeiro do PegaeFazFree, a cobrança do cliente e o repasse ao prestador podem ocorrer em momentos diferentes. Após a confirmação do pagamento, o valor destinado ao prestador permanece sem repasse até que sejam atendidas as condições operacionais de conclusão previstas pela plataforma.

O prestador poderá registrar a conclusão do trabalho e enviar, quando solicitado, comprovação pela plataforma. Após a confirmação de conclusão pelo cliente ou outra liberação válida prevista no sistema, o PegaeFazFree poderá solicitar ao provedor financeiro a transferência do valor líquido devido ao prestador para sua conta conectada.

• O repasse depende da confirmação do pagamento e da situação regular da conta financeira conectada do prestador.

• O valor líquido do prestador considera a taxa de serviço da plataforma quando ela for aplicável.

• Prazos bancários, disponibilidade de saldo, verificações, bloqueios ou análises do provedor financeiro podem afetar o momento em que o prestador efetivamente recebe os recursos.

• O PegaeFazFree poderá impedir ou suspender a liberação em caso de suspeita de fraude, disputa, estorno, inconsistência ou necessidade de análise.

A expressão “pagamento acompanhado” descreve o fluxo operacional adotado pela plataforma. Ela não deve ser interpretada como promessa de conta bancária, investimento, depósito remunerado ou serviço independente de custódia financeira.

7. Taxa da plataforma

O PegaeFazFree poderá cobrar taxa de serviço sobre operações realizadas pela plataforma. A alíquota, eventual período promocional, desconto ou isenção aplicável será aquela informada ao usuário no fluxo da contratação ou conforme as regras vigentes no momento da operação.

Campanhas promocionais podem reduzir ou zerar temporariamente a taxa. O encerramento de uma promoção não gera direito à manutenção permanente da condição promocional para operações futuras.

8. Cancelamentos, reembolsos, estornos e disputas

Pedidos de cancelamento, reembolso, estorno ou contestação poderão ser analisados conforme o estágio do serviço, o status do pagamento, as evidências disponíveis, as regras do provedor financeiro e os direitos previstos na legislação aplicável.

• Antes do repasse ao prestador, um reembolso aprovado poderá ser processado diretamente sobre a cobrança, observadas as condições da operação.

• Depois de um repasse, eventual reembolso poderá exigir também a reversão total ou parcial da transferência realizada ao prestador.

• Reembolsos parciais poderão depender de análise específica do caso.

• Em caso de contestação do pagamento, chargeback, suspeita de fraude ou disputa, o PegaeFazFree poderá solicitar documentos, mensagens, fotos e outros registros relacionados ao serviço.

• O processamento final pode depender do provedor financeiro, da instituição emissora, das regras do meio de pagamento e de prazos externos ao PegaeFazFree.

Nenhuma disposição destes termos busca afastar direitos obrigatórios previstos na legislação brasileira aplicável ao caso concreto.

9. Acesso empresarial a currículos

Quando essa funcionalidade estiver disponível, contas do tipo empresa poderão adquirir acesso temporário ao recurso de consulta de currículos disponibilizados por prestadores para finalidades relacionadas a oportunidades profissionais, recrutamento e contratação.

• A aquisição do acesso não representa compra, cessão, venda ou transferência de propriedade sobre currículos ou dados pessoais.

• A empresa recebe apenas uma autorização limitada e temporária de consulta, dentro das funcionalidades e finalidades permitidas pelo PegaeFazFree.

• É proibido revender, comercializar, publicar, distribuir em massa, copiar de forma indiscriminada, formar banco de dados paralelo ou utilizar currículos e dados pessoais para finalidade incompatível com aquela disponibilizada pela plataforma.

• A empresa é responsável pelo uso que fizer das informações acessadas e deverá observar a legislação aplicável, a finalidade do acesso e os direitos dos titulares.

• Após o encerramento do período contratado, o acesso aos currículos poderá ser bloqueado automaticamente até uma nova aquisição válida.

• Preço, duração, eventual renovação, forma de pagamento e demais condições do acesso serão apresentados antes da confirmação da compra e poderão ser alterados para compras futuras.

• O meio de faturamento disponível pode variar de acordo com o canal de distribuição do aplicativo, a região, a loja de aplicativos e as regras aplicáveis no momento da compra.

Compras realizadas por uma loja de aplicativos ou por outro provedor de faturamento também podem estar sujeitas aos termos, procedimentos de reembolso e regras daquele provedor.

10. Obrigações do prestador

O prestador é responsável pela execução do serviço que aceitar, pela qualidade do trabalho, pelas informações profissionais que divulgar e pelo cumprimento das obrigações legais aplicáveis à sua atividade.

• O prestador deve aceitar apenas serviços para os quais tenha capacidade, experiência e condições de execução.

• Licenças, autorizações, registros profissionais, tributos, notas fiscais e demais obrigações específicas da atividade são de responsabilidade de quem estiver legalmente obrigado a cumpri-las.

• É proibido declarar um serviço como concluído quando ele não tiver sido efetivamente realizado.

• Comprovações de conclusão devem corresponder ao serviço realizado e não podem ser falsificadas ou manipuladas.

11. Condutas proibidas

Para proteger a comunidade e o funcionamento da plataforma, não são permitidas condutas que coloquem usuários, terceiros ou o PegaeFazFree em risco.

• Fraude, golpe, ameaça, assédio, discriminação, abuso ou prática ilegal.

• Uso de dados falsos, documentos de terceiros sem autorização ou informações enganosas.

• Solicitação indevida de senhas, códigos, credenciais, dados bancários ou outras informações sensíveis.

• Tentativa de invadir, copiar, danificar, sobrecarregar, automatizar abusivamente ou burlar mecanismos da plataforma.

• Manipulação de propostas, avaliações, comprovantes, pagamentos ou qualquer registro utilizado pela plataforma.

• Publicação de conteúdo ilegal, ofensivo, perigoso ou incompatível com a finalidade do aplicativo.

12. Avaliações e reputação

As avaliações ajudam a construir confiança entre usuários. Comentários devem representar uma experiência real, ser relacionados ao serviço e respeitar as demais pessoas.

• Avaliações falsas, ofensivas, fraudulentas ou manipuladas podem ser removidas.

• Usuários podem sofrer medidas de moderação em caso de abuso do sistema de avaliações.

• A reputação poderá influenciar a confiança, destaque e experiência do perfil dentro da plataforma.

13. Segurança, moderação e suporte

O PegaeFazFree poderá analisar comportamentos suspeitos, denúncias, mensagens, registros de serviço e eventos relacionados à segurança para proteger usuários, prestar suporte e reduzir riscos.

• Contas podem ser advertidas, limitadas, suspensas ou bloqueadas quando houver fundamento de segurança, fraude ou violação destes termos.

• Mensagens, propostas, fotos, comprovantes e denúncias poderão ser analisados quando necessários para suporte, segurança, moderação ou solução de uma ocorrência.

• O suporte poderá solicitar informações adicionais para compreender e analisar uma situação.

14. Relação entre os usuários e limites da plataforma

O PegaeFazFree fornece a infraestrutura digital de conexão, comunicação e, quando disponível, processamento e organização do fluxo de pagamento. A contratação e a execução do serviço ocorrem entre os usuários envolvidos.

O PegaeFazFree não garante resultado específico do serviço, mas poderá aplicar recursos de suporte, moderação, pagamento acompanhado, análise de ocorrências e outras medidas previstas na plataforma.

Essas disposições não limitam responsabilidades que não possam ser afastadas pela legislação aplicável.

15. Fase de testes, pré-lançamento e melhorias

Durante fases de teste, pré-lançamento, ajustes ou evolução do produto, funcionalidades podem ser modificadas, suspensas, substituídas ou melhoradas. Alterações relevantes que afetem direitos, cobranças ou condições de uso poderão exigir atualização destes termos ou comunicação adequada ao usuário.

16. Alterações destes termos

Estes Termos de Uso podem ser atualizados para refletir mudanças na plataforma, novas funcionalidades, meios de pagamento, ajustes operacionais ou adequações legais. A versão vigente ficará disponível nesta página.

Última atualização: outubro de 2026.

Pagamento acompanhado

Segurança

Transparência

Dúvidas sobre os termos?

Fale com o suporte oficial do PegaeFazFree para solicitar orientação sobre o uso da plataforma, pagamentos ou uma ocorrência.
''';

const String protectionText = '''
Para clientes

Antes de contratar, confira as informações do serviço e mantenha o máximo possível da negociação registrado no aplicativo.

• Confira proposta, valor, descrição, prazo e avaliações antes de aceitar.

• Use o chat do PegaeFazFree para combinar detalhes importantes do atendimento.

• Quando houver pagamento oficial disponível, prefira o fluxo do aplicativo em vez de transferências combinadas por fora.

• Não compartilhe senha, código de autenticação, dados completos do cartão ou documentos sem necessidade.

• Confirme a conclusão somente depois de verificar que o serviço foi realmente realizado.

Para prestadores

Proteja sua conta, seus recebimentos e sua reputação mantendo propostas e registros compatíveis com o serviço que realmente será executado.

• Mantenha seu perfil atualizado e envie propostas claras, com valor e condições reais.

• Não peça dados completos de cartão, senhas ou códigos de autenticação do cliente.

• Não marque um serviço como concluído antes de terminar o trabalho.

• Quando a plataforma solicitar comprovação de conclusão, envie apenas informações relacionadas ao serviço realizado.

• Cadastro financeiro e documentos exigidos para receber pela Stripe devem ser preenchidos no ambiente oficial de onboarding apresentado pela plataforma, e não enviados pelo chat a outros usuários.

Para empresas

Empresas devem utilizar dados e currículos acessados pela plataforma de forma responsável e apenas para finalidades compatíveis com oportunidades profissionais, recrutamento, contratação e relacionamento profissional.

• Confira histórico, perfil e informações profissionais antes de avançar em uma contratação.

• Não solicite senhas, códigos ou dados financeiros desnecessários de candidatos ou prestadores.

• Não venda, publique, distribua em massa, forme bancos de dados paralelos ou encaminhe currículos e dados pessoais a terceiros fora da finalidade permitida pela plataforma, salvo quando houver base adequada para isso.

• Utilize os canais oficiais para pagamentos, suporte e dúvidas relacionadas à conta empresarial.

Conta, documentos e acesso

Grande parte da segurança começa protegendo a própria conta e reconhecendo os ambientes oficiais utilizados pelo PegaeFazFree.

• Nunca informe sua senha do PegaeFazFree para outro usuário ou suposto atendente.

• Não compartilhe códigos recebidos por e-mail, SMS, autenticação ou recuperação de conta.

• Documentos exigidos pela Stripe para habilitar recebimentos são enviados diretamente no ambiente oficial da Stripe apresentado pelo fluxo da plataforma.

• Desconfie de links recebidos por mensagens externas dizendo que é necessário “liberar pagamento”, “confirmar repasse” ou “desbloquear conta”.

• Em caso de dúvida, interrompa a ação e procure o suporte oficial.

Sinais de alerta

Algumas situações merecem atenção imediata. Não continue a negociação quando houver pressão, pedido de informação sensível ou tentativa de tirar todo o processo da plataforma.

• 🚫 Pressão para pagar ou receber totalmente por fora quando existe fluxo oficial

• 🔑 Pedido de senha, código de autenticação ou acesso à conta

• 💳 Solicitação de número completo do cartão ou código de segurança pelo chat

• 📄 Pedido para enviar documentos da Stripe diretamente a outro usuário

• 💸 Cobrança inesperada, valor diferente do combinado ou promessa de “liberação” mediante pagamento extra

• ⚠️ Ameaça, assédio, comportamento ofensivo ou tentativa de golpe

Como os recursos da plataforma ajudam na proteção?

Histórico no aplicativo

Chat, propostas, contrapropostas, status e registros de conclusão ajudam a documentar o que aconteceu no serviço.

Pagamento oficial

Quando disponível, o fluxo oficial registra o status da operação e separa a confirmação do pagamento da etapa de repasse ao prestador.

Suporte e análise

Em caso de problema, registros do serviço podem ajudar a equipe a entender a situação e orientar os próximos passos.

Teve algum problema?

Se algo não estiver de acordo com o combinado, evite apagar mensagens ou comprovantes relacionados ao serviço. Esses registros podem ser importantes para suporte, denúncia ou análise de uma operação.

• 1️⃣ Interrompa qualquer nova transferência ou envio de dado sensível

• 2️⃣ Guarde mensagens, proposta, fotos e informações relacionadas ao serviço

• 3️⃣ Use os recursos de denúncia ou procure o suporte oficial

• 4️⃣ Em situação de risco físico ou crime, procure também as autoridades competentes

Precisa de ajuda?

Fale com o suporte do PegaeFazFree e envie os detalhes relevantes da situação. Regras completas sobre pagamentos e tratamento de dados estão disponíveis nos Termos de Uso e na Política de Privacidade.
''';

// 👇 COLA AQUI
Future<void> verificarUsuarioBloqueado() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  final response = await supabase
      .from('profiles')
      .select('is_blocked')
      .eq('id', user.id)
      .single();

  if (response['is_blocked'] == true) {
    throw Exception('Usuário bloqueado');
  }
}
bool mensagemSuspeita(String texto) {
  final textoLower = texto.toLowerCase();

  final palavrasProibidas = [
    'whatsapp',
    'zap',
    'chama no zap',
    'me chama',
    'por fora',
    'direto',
    'pix por fora',
    'telefone',
    'número',
  ];

  for (final palavra in palavrasProibidas) {
    if (textoLower.contains(palavra)) {
      return true;
    }
  }
  return false;
}

Future<void> enforceSuspiciousMessageBlock(String mensagem) async {
  if (mensagemSuspeita(mensagem)) {
    final user = supabase.auth.currentUser;

    if (user != null) {
      await supabase
          .from('profiles')
          .update({'is_blocked': true})
          .eq('id', user.id);

      throw Exception('Usuário bloqueado por atividade suspeita');
    }
  }
}
