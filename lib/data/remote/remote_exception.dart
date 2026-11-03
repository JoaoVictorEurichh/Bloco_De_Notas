import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

/// Tipos de falha ao acessar o Firebase, já traduzidos para o domínio do app.
enum RemoteErrorKind {
  /// Sem internet ou servidor indisponível.
  offline,

  /// A operação demorou mais que o limite configurado.
  timeout,

  /// As regras de segurança do Firestore recusaram o acesso.
  permissionDenied,

  /// Sessão expirada / usuário não autenticado.
  unauthenticated,

  /// Firebase não foi configurado/inicializado no aparelho.
  notConfigured,

  unknown,
}

/// Exceção única lançada pela camada remota. As telas nunca recebem
/// `FirebaseException`, `SocketException` ou `TimeoutException` diretamente.
class RemoteException implements Exception {
  final RemoteErrorKind kind;
  final Object? cause;

  const RemoteException(this.kind, [this.cause]);

  /// Indica que vale a pena tentar novamente mais tarde.
  bool get isTransient =>
      kind == RemoteErrorKind.offline || kind == RemoteErrorKind.timeout;

  String get message => switch (kind) {
        RemoteErrorKind.offline =>
          'Sem conexão com o Firebase. As alterações ficam salvas no aparelho '
              'e serão enviadas quando a conexão voltar.',
        RemoteErrorKind.timeout =>
          'O Firebase demorou para responder. Tentaremos novamente.',
        RemoteErrorKind.permissionDenied =>
          'Acesso negado pelas regras de segurança do Firestore.',
        RemoteErrorKind.unauthenticated =>
          'Sua sessão expirou. Entre novamente para sincronizar.',
        RemoteErrorKind.notConfigured =>
          'Firebase não configurado. Veja o README para configurar o projeto.',
        RemoteErrorKind.unknown => 'Erro inesperado ao acessar o Firebase.',
      };

  /// Converte qualquer erro vindo do SDK em [RemoteException].
  factory RemoteException.from(Object error) {
    if (error is RemoteException) return error;
    if (error is TimeoutException) {
      return RemoteException(RemoteErrorKind.timeout, error);
    }
    if (error is SocketException) {
      return RemoteException(RemoteErrorKind.offline, error);
    }
    if (error is FirebaseException) {
      final kind = switch (error.code) {
        'unavailable' || 'network-request-failed' => RemoteErrorKind.offline,
        'deadline-exceeded' => RemoteErrorKind.timeout,
        'permission-denied' => RemoteErrorKind.permissionDenied,
        'unauthenticated' => RemoteErrorKind.unauthenticated,
        'no-app' => RemoteErrorKind.notConfigured,
        _ => RemoteErrorKind.unknown,
      };
      return RemoteException(kind, error);
    }
    return RemoteException(RemoteErrorKind.unknown, error);
  }

  @override
  String toString() => 'RemoteException(${kind.name}, $cause)';
}
