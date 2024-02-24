/// A delegate that may be used to serialize and deserialize data from generic
/// types [DataType] and [SerializedDataType].
///
/// Serialization occurs from [DataType] -> [SerializedDataType].
/// Deserialization occurs from [SerializedDataType] -> [DataType].
///
/// This is used by `StorageService` to convert data passed to it in an
/// application-usable (i.e., hydrated [DataType] format) to a storage-usable
/// (i.e., dehydrated [SerializedDataType] format) and vice versa.
abstract class SerializationService<DataType, SerializedDataType> {
  /// Instantiates a new instance of [DataType].
  DataType instantiate();

  /// Serializes data into [SerializedDataType] format, from [DataType] format,
  /// for storage.
  SerializedDataType? serialize(final DataType? data);

  /// Deserializes data from [SerializedDataType] format, into [DataType]
  /// format, for use by the application.
  DataType? deserialize(final SerializedDataType? data);
}
