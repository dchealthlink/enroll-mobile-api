$(function () {
  $(document).on('click', 'a.qle-menu-item', function() {
    $('#qle_flow_info #qle-menu').hide();
    $('.qle-details-title').html($(this).html());
    $('#event-title').html($(this).html());
    $('#change_plan').val($(this).html());
    init_datepicker_for_qle_date();
    $('#qle-details').removeClass('hidden');
    $('.qle-form').removeClass('hidden');
  });

	$(document).on('click', '#qle-details .close-popup, #qle-details .cancel, #existing_coverage, #new_plan', function() {
		$('#qle-details').addClass('hidden');
		$('#qle-details .success-info, #qle-details .error-info').addClass('hidden');
    $('#qle-details .qle-form').removeClass('hidden');
    $("#qle_date").val("");

		$('#qle_flow_info #qle-menu').show();
	});

	// Disable form submit on pressing Enter, instead click Submit link
  $('#qle_form').on('keyup keypress', function(e) {
    var code = e.keyCode || e.which;
    if (code == 13) { 
      e.preventDefault();
      $("#qle_submit").click();
      return false;
    }
  });

	/* QLE Date Validator */
	$(document).on('click', '#qle_submit', function() {
		if(check_qle_date()) {
			$('#qle_date').removeClass('input-error');
			get_qle_date();
		} else {
			$('#qle_date').addClass('input-error');
			$('.success-info').addClass('hidden');
			$('.error-info').addClass('hidden');
		}
	});

	function check_qle_date() {
		var date_value = $('#qle_date').val();
		if(date_value == "" || isNaN(Date.parse(date_value))) { return false; }
		return true;
	}

  function get_qle_date() {
    qle_string = $(".qle-details-title").html();
    qle_type = qle_string.substring(1, qle_string.length-1);

    $.ajax({
      type: "GET",
      data:{date_val: $("#qle_date").val(), qle_type: qle_type},
      url: "/consumer_profiles/check_qle_date.js"
    });
  }

  function init_datepicker_for_qle_date() {
    var target = $('.qle-date-picker');
    var dateMin = $(target).attr("data-date-min");
    var dateMax = $(target).attr("data-date-max");
    var cur_qle_title = $('.qle-details-title').html();
    if (cur_qle_title === "I've had a baby" || cur_qle_title === "Death" || cur_qle_title === "I've married") {
      dateMax = "+0d";
    }

    $(target).val('');
    $(target).datepicker('destroy');
    $(target).datepicker({
      changeMonth: true,
      changeYear: true,
      dateFormat: 'mm/dd/yy',
      minDate: dateMin,
      maxDate: dateMax});
  }

	$(document).on('click', '#qle_continue_button', function() {
		$('#qle_flow_info .initial-info').hide();
		$('#qle_flow_info .qle-info').removeClass('hidden');
	})
});
