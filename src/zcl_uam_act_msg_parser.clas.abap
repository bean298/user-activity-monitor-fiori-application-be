CLASS zcl_uam_act_msg_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CLASS-METHODS parse_audit_message
      IMPORTING
        VALUE(im_area)    TYPE rslgarea
        VALUE(im_subid)   TYPE rslgsubid
        !im_sal_data      TYPE string
      RETURNING
        VALUE(re_message) TYPE string .

    CLASS-METHODS parse_dump_message
      IMPORTING
        !im_flist         TYPE string
      EXPORTING
        !ex_tcode         TYPE string
      RETURNING
        VALUE(re_message) TYPE string .

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_uam_act_msg_parser IMPLEMENTATION.
  METHOD parse_audit_message.
    " Variables declaration
    DATA: lv_template    TYPE tsl1t-txt,        " Message template from DB
          lt_variables   TYPE TABLE OF string,  " Table of split variables
          lv_final_msg   TYPE string,           " Final formatted message string
          lv_index       TYPE i,                " Loop index counter
          lv_char        TYPE c,                " Alphabet character for placeholder
          lv_placeholder TYPE string,           " Placeholder string (e.g., &A, &B)
          lv_actvt_text  TYPE tactt-ltext.      " Translated activity text

    " 1. Get message template from table TSL1T based on logon language (sy-langu)
    SELECT SINGLE txt
      INTO lv_template
      FROM tsl1t
      WHERE spras = sy-langu
        AND area  = im_area
        AND subid = im_subid.

    " If template is not found or no variable data -> return original string
    IF sy-subrc <> 0 OR im_sal_data IS INITIAL.
      re_message = im_sal_data.
      RETURN.
    ENDIF.

    lv_final_msg = lv_template.

    " 2. Split SAL_DATA string based on '&' character into a table
    SPLIT im_sal_data AT '&' INTO TABLE lt_variables.

    " 3. Loop through variables to replace placeholders and translate activity code
    lv_index = 1.
    LOOP AT lt_variables INTO DATA(lv_var).
      " --- Translate Activity Code (01, 02, 03...) to Text (Create, Change, Display...) ---
      " Check if the variable is exactly 2 characters long
      IF strlen( lv_var ) = 2 AND lv_var CO '0123456789'.
        SELECT SINGLE ltext
          FROM tactt INTO lv_actvt_text
          WHERE spras = sy-langu
          AND actvt = lv_var.
        IF sy-subrc = 0.
          lv_var = lv_actvt_text. " Replace number with actual text
        ENDIF.
      ENDIF.
      " -----------------------------------------------------------------------------

      " Create placeholder text to search for (like &A, &B, &C...)
      " System variable sy-abcde contains 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      DATA(lv_offset) = lv_index - 1.
      lv_char = sy-abcde+lv_offset(1).
      lv_placeholder = |&{ lv_char }|.

      " Find the placeholder (e.g., &A) in the template and replace it with real data
      REPLACE FIRST OCCURRENCE OF lv_placeholder IN lv_final_msg WITH lv_var.

      lv_index = lv_index + 1.
    ENDLOOP.

    " 4. Return the final formatted message
    re_message = lv_final_msg.
  ENDMETHOD.


  METHOD parse_dump_message.
    " Variables declaration
    DATA: lv_flist_len TYPE i,          " Length of the raw FLIST string
          lv_offset    TYPE i VALUE 0,  " Pointer offset for string scanning
          lv_tag       TYPE c LENGTH 2, " 2-character Tag from block
          lv_len_str   TYPE c LENGTH 3, " 3-character Length definition
          lv_len       TYPE i,          " Integer length of the block value
          lv_val       TYPE string,     " Safely extracted block value
          lv_check_len TYPE i,          " Boundary check variable
          lv_len_text  TYPE i.          " Variable for trailing dot removal

    " Variables to store extracted dump attributes
    DATA: lv_err_id TYPE string,        " Error ID (e.g., COMPUTE_INT_ZERODIVIDE)
          lv_prog   TYPE string,        " Active Program
          lv_line   TYPE string.        " Active Line Number

    " Default fallback message
    re_message = TEXT-001.

    lv_flist_len = strlen( im_flist ).

    " Exit immediately if the raw string is empty
    IF lv_flist_len = 0.
      RETURN.
    ENDIF.

    " 1. Sequential scanning loop to parse data blocks from the FLIST string
    WHILE lv_offset < lv_flist_len.

      " Boundary check before extracting the 2-character Tag
      lv_check_len = lv_offset + 2.
      IF lv_check_len > lv_flist_len. EXIT. ENDIF.

      lv_tag = im_flist+lv_offset(2).
      lv_offset = lv_offset + 2.

      " Boundary check before extracting the 3-character Length
      lv_check_len = lv_offset + 3.
      IF lv_check_len > lv_flist_len. EXIT. ENDIF.

      lv_len_str = im_flist+lv_offset(3).

      " If the length string contains non-numeric characters, it's corrupted -> Exit
      IF NOT lv_len_str CO '0123456789'. EXIT. ENDIF.

      lv_len = lv_len_str.
      lv_offset = lv_offset + 3.

      " Boundary check: Does the requested length exceed the remaining string?
      lv_check_len = lv_offset + lv_len.
      IF lv_check_len > lv_flist_len.
        " If it exceeds, truncate the requested length to the remaining available characters
        lv_len = lv_flist_len - lv_offset.
      ENDIF.

      " Safely extract the block value
      IF lv_len > 0.
        lv_val = im_flist+lv_offset(lv_len).
      ELSE.
        lv_val = ''.
      ENDIF.

      " 2. Categorize and store extracted values based on recognized Tags
      CASE lv_tag.
        WHEN 'FC'. " Error ID
          lv_err_id = lv_val.
        WHEN 'AP'. " Active Program (format: ProgramName=IncludeName)
          SPLIT lv_val AT '=' INTO lv_prog DATA(lv_dummy) ##NEEDED.
        WHEN 'AL'. " Active Line Number
          lv_line = lv_val.
          SHIFT lv_line LEFT DELETING LEADING '0'. " Remove leading zeros
        WHEN 'TC'. " Transaction Code
          EX_tcode = lv_val.
      ENDCASE.

      " Move the offset pointer to the next block
      lv_offset = lv_offset + lv_len.
    ENDWHILE.

    " Declaration for readable short text and program replacement flag
    DATA: lv_short_text TYPE snapt-tline,
          lv_prog_added TYPE abap_bool VALUE abap_false.

    " 3. Translate technical error ID into human-readable Short Text
    IF lv_err_id IS NOT INITIAL.
      CLEAR lv_short_text.

      " Query SAP's standard dump dictionary table (SNAPT)
      SELECT SINGLE tline
        INTO lv_short_text
        FROM snapt
        WHERE langu = sy-langu   " Fetch based on current logon language
          AND errid = lv_err_id  " Match the technical Error ID
          AND ttype = 'K'.       " 'K' denotes Short Text description

      " Fallback: Use technical ID if dictionary translation is missing
      IF sy-subrc <> 0.
        lv_short_text = lv_err_id.
      ELSE.
        " --- PROCESS SAP DYNAMIC VARIABLE '&P1' ---
        IF lv_short_text CS '&P1'.
          REPLACE ALL OCCURRENCES OF '&P1.' IN lv_short_text WITH lv_prog.
          REPLACE ALL OCCURRENCES OF '&P1'  IN lv_short_text WITH lv_prog.

          lv_prog_added = abap_true. " Set flag indicating the program name is already embedded
        ENDIF.
      ENDIF.

      " --- STRIP TRAILING DOT FROM THE MESSAGE (IF EXISTS) ---
      lv_len_text = strlen( lv_short_text ).
      IF lv_len_text > 0.
        lv_len_text = lv_len_text - 1. " Index of the last character
        IF lv_short_text+lv_len_text(1) = '.'.
          lv_short_text = lv_short_text(lv_len_text).
        ENDIF.
      ENDIF.
    ENDIF.

    " 4. Assemble the final, user-friendly alert message
    IF lv_err_id IS NOT INITIAL.

      IF lv_prog IS NOT INITIAL AND lv_prog_added = abap_false.
        " SCENARIO 1: Standard text didn't contain '&P1', so we manually append the program name
        IF lv_line IS NOT INITIAL.
          CONCATENATE TEXT-002 lv_short_text TEXT-003 lv_prog TEXT-004 lv_line ')'
            INTO re_message SEPARATED BY space.
        ELSE.
          CONCATENATE TEXT-002 lv_short_text TEXT-003 lv_prog
            INTO re_message SEPARATED BY space.
        ENDIF.

      ELSE.
        " SCENARIO 2: '&P1' was already replaced (or no program exists).
        IF lv_line IS NOT INITIAL.
          CONCATENATE TEXT-002 lv_short_text TEXT-004 lv_line ')'
            INTO re_message SEPARATED BY space.
        ELSE.
          CONCATENATE TEXT-002 lv_short_text INTO re_message SEPARATED BY space.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
