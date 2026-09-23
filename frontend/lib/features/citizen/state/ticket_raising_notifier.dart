import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../shared/models/ticket_model.dart';
import '../../../core/network/api_client.dart';

class TicketRaisingState {
  final bool isSubmitting;
  final String? error;
  final TicketModel? createdTicket;

  TicketRaisingState({
    this.isSubmitting = false,
    this.error,
    this.createdTicket,
  });

  TicketRaisingState copyWith({
    bool? isSubmitting,
    String? error,
    TicketModel? createdTicket,
    bool clearCreated = false,
  }) {
    return TicketRaisingState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      createdTicket: clearCreated ? null : (createdTicket ?? this.createdTicket),
    );
  }
}

class TicketRaisingNotifier extends StateNotifier<TicketRaisingState> {
  final ApiClient _apiClient;

  TicketRaisingNotifier(this._apiClient) : super(TicketRaisingState());

  Future<TicketModel?> raiseTicket({
    required String facilityId,
    required int reporterId,
    required List<String> issueCategories,
    String? description,
    required double reporterLatitude,
    required double reporterLongitude,
    String? mediaUrl,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, clearCreated: true);
    try {
      final response = await _apiClient.dio.post('/tickets', data: {
        'facility_id': facilityId,
        'reporter_id': reporterId,
        'issue_categories': issueCategories,
        'description': description,
        'reporter_latitude': reporterLatitude,
        'reporter_longitude': reporterLongitude,
        'media_url': mediaUrl ?? 'https://storage.googleapis.com/civic-media/live_camera_proof.jpg',
        'is_live_camera': true, // Strictly camera-only
      });
      final ticket = TicketModel.fromJson(response.data);
      state = state.copyWith(isSubmitting: false, createdTicket: ticket);
      return ticket;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Failed to submit report. Please try again.';
      state = state.copyWith(isSubmitting: false, error: msg.toString());
      return null;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'Connection error: Unable to reach municipal server.');
      return null;
    }
  }
}

final ticketRaisingProvider = StateNotifierProvider<TicketRaisingNotifier, TicketRaisingState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TicketRaisingNotifier(apiClient);
});
