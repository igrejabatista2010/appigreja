import 'package:church_app/core/error/failures.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

/// Um caso de uso por classe. O repositório já devolve `Either`, então nenhuma
/// exceção chega ao Bloc.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Para casos de uso sem parâmetros.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
