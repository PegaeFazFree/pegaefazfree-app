# PegaeFazFree — preparação iOS

Este pacote está preparado para o primeiro build iOS no Codemagic com:
- Bundle ID: br.com.pegaefazfree
- iOS mínimo: 15.0
- permissões de câmera, fotos, localização e Face ID
- URL scheme: pegaefazfree://
- Background Modes para notificações remotas
- codemagic.yaml para build inicial sem assinatura

## Ainda falta antes do iOS funcionar completamente
1. Registrar no Firebase um app iOS com Bundle ID `br.com.pegaefazfree`.
2. Baixar `GoogleService-Info.plist` e adicionar em `ios/Runner/`.
3. Atualizar/regerar `lib/firebase_options.dart` para o novo app iOS.
4. Para push real em iPhone, configurar APNs no Apple Developer/Firebase.
5. Para TestFlight/App Store, configurar assinatura Apple no Codemagic.

O primeiro workflow `ios-unsigned-check` serve apenas para validar a compilação sem assinatura.
